const assert = require("node:assert/strict");
const { test } = require("node:test");
const { createApp } = require("../src/app");
const { MemoryStore } = require("../src/store/memory");

async function startApp(store = new MemoryStore()) {
  const app = createApp({
    store,
    verifyFirebaseToken: async (token) => {
      if (token === "bad") throw new Error("invalid");
      if (token === "student-b") {
        return { firebaseUid: "other-student-firebase", name: "Other Student", email: "other@example.test" };
      }
      if (token === "admin") {
        return { firebaseUid: "admin-firebase", name: "Lim Admin", email: "admin@example.test" };
      }
      return { firebaseUid: "student-firebase", name: "Test Student", email: "student@example.test" };
    },
  });
  const server = app.listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  return { base, server, store };
}

async function request(base, method, route, options = {}) {
  const headers = { Authorization: "Bearer student", ...(options.headers || {}) };
  if (options.body !== undefined) {
    headers["Content-Type"] = "application/json";
  }
  const response = await fetch(`${base}${route}`, {
    method,
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  const contentType = response.headers.get("content-type") || "";
  return { response, body: contentType.includes("application/json") ? await response.json() : await response.text() };
}

function addDays(date, days) {
  const result = new Date(`${date}T00:00:00Z`);
  result.setUTCDate(result.getUTCDate() + days);
  return result.toISOString().slice(0, 10);
}

test("profile requires Firebase authentication", async (t) => {
  const { base, server } = await startApp();
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const missing = await fetch(`${base}/api/v1/me`);
  assert.equal(missing.status, 401);
  const bad = await fetch(`${base}/api/v1/me`, { headers: { Authorization: "Bearer bad" } });
  assert.equal(bad.status, 401);
});

test("reports a database outage instead of falling back to memory", async (t) => {
  const app = createApp({
    store: {
      async getOrCreateProfile() {
        throw Object.assign(new Error("MySQL connection refused."), { code: "ECONNREFUSED" });
      },
    },
    verifyFirebaseToken: async () => ({ firebaseUid: "student-firebase" }),
  });
  const server = app.listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const response = await fetch(`http://127.0.0.1:${server.address().port}/api/v1/entries`, {
    headers: { Authorization: "Bearer student" },
  });
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    error: {
      code: "DATABASE_UNAVAILABLE",
      message: "MySQL is unavailable; the request was not saved.",
    },
  });
});

test("creates and completes a deadline", async (t) => {
  const { base, server } = await startApp();
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const created = await request(base, "POST", "/api/v1/entries", {
    body: {
      kind: "deadline",
      title: "Submit MAD report",
      description: "Upload final PDF",
      timeZone: "Asia/Kuala_Lumpur",
      dueAt: "2026-11-25T09:00:00Z",
      reminderMinutes: 30,
      location: null,
      photoId: null,
    },
  });
  assert.equal(created.response.status, 201);
  assert.equal(created.body.data.kind, "deadline");
  assert.equal(created.body.data.isCompleted, false);

  const completed = await request(base, "PUT", `/api/v1/entries/${created.body.data.id}/completion`, {
    body: { isCompleted: true },
  });
  assert.equal(completed.response.status, 200);
  assert.equal(completed.body.data.isCompleted, true);
});

test("dashboard lists only owned deadlines with date-only dueDate and no required filters", async (t) => {
  const { base, server } = await startApp();
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const created = await request(base, "POST", "/api/v1/entries", {
    body: { kind: "deadline", title: "Submit MAD report", dueDate: "2026-11-30" },
  });
  assert.equal(created.response.status, 201);

  const listed = await request(base, "GET", "/api/v1/entries");
  assert.equal(listed.response.status, 200);
  assert.deepEqual(listed.body, {
    data: [{ id: created.body.data.id, title: "Submit MAD report", dueDate: "2026-11-30" }],
  });

  const otherStudent = await request(base, "GET", "/api/v1/entries", {
    headers: { Authorization: "Bearer student-b" },
  });
  assert.equal(otherStudent.response.status, 200);
  assert.deepEqual(otherStudent.body, { data: [] });

  const routine = await request(base, "POST", "/api/v1/entries", {
    body: {
      kind: "routine",
      title: "Study",
      startDate: "2026-11-25",
      startTime: "20:00",
      endTime: "21:00",
      repeat: "none",
      weekdays: [],
    },
  });
  assert.equal(routine.response.status, 201);
  const ranged = await request(base, "GET", "/api/v1/entries?from=2026-11-25&to=2026-11-30");
  assert.equal(ranged.response.status, 200);
  assert.ok(ranged.body.data.items.some((entry) => entry.id === routine.body.data.id));
});

test("generates stable weekly occurrence IDs and completes one occurrence", async (t) => {
  const { base, server } = await startApp();
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const created = await request(base, "POST", "/api/v1/entries", {
    body: {
      kind: "routine",
      title: "Study",
      description: null,
      startDate: "2026-11-25",
      startTime: "20:00",
      endTime: "21:00",
      repeat: "weekly",
      weekdays: [1, 3, 5],
      repeatUntil: null,
      reminderMinutes: 15,
      location: null,
      photoId: null,
    },
  });
  assert.equal(created.response.status, 201);

  const listed = await request(base, "GET", "/api/v1/routine-occurrences?from=2026-11-25T00:00:00Z&to=2026-12-02T00:00:00Z");
  assert.equal(listed.response.status, 200);
  assert.ok(listed.body.data.items.length >= 3);
  const firstId = listed.body.data.items[0].id;
  const completed = await request(base, "PUT", `/api/v1/routine-occurrences/${firstId}/completion`, {
    body: { isCompleted: true },
  });
  assert.equal(completed.response.status, 200);
  assert.equal(completed.body.data.isCompleted, true);

  const relisted = await request(base, "GET", "/api/v1/routine-occurrences?from=2026-11-25T00:00:00Z&to=2026-12-02T00:00:00Z");
  const remaining = relisted.body.data.items.find((item) => item.id !== firstId);
  assert.equal(remaining.isCompleted, false);
});

test("editing a weekly routine removes obsolete future dates and preserves completed history", async (t) => {
  const { base, server } = await startApp();
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const today = new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const todayWeekday = (new Date(`${today}T00:00:00Z`).getUTCDay() + 6) % 7;
  const startDate = addDays(today, -(todayWeekday + 7));
  const repeatUntil = addDays(startDate, 28);
  const created = await request(base, "POST", "/api/v1/entries", {
    body: {
      kind: "routine",
      title: "Study",
      startDate,
      startTime: "20:00",
      endTime: "21:00",
      repeat: "weekly",
      weekdays: [1],
      repeatUntil,
    },
  });
  assert.equal(created.response.status, 201);

  const oldOccurrences = await request(
    base,
    "GET",
    `/api/v1/routine-occurrences?from=${startDate}&to=${addDays(repeatUntil, 1)}`,
  );
  const completedMonday = oldOccurrences.body.data.items.find((item) => item.date === startDate);
  assert.ok(completedMonday);
  await request(base, "PUT", `/api/v1/routine-occurrences/${completedMonday.id}/completion`, {
    body: { isCompleted: true },
  });

  const updated = await request(base, "PATCH", `/api/v1/entries/${created.body.data.id}`, {
    body: { weekdays: [3] },
  });
  assert.equal(updated.response.status, 200);

  const revisedOccurrences = await request(
    base,
    "GET",
    `/api/v1/routine-occurrences?from=${startDate}&to=${addDays(repeatUntil, 1)}`,
  );
  const occurrences = revisedOccurrences.body.data.items;
  assert.equal(occurrences.find((item) => item.id === completedMonday.id)?.isCompleted, true);
  assert.ok(occurrences.some((item) => item.date > today && item.date !== startDate &&
    (new Date(`${item.date}T00:00:00Z`).getUTCDay() + 6) % 7 === 2));
  assert.equal(occurrences.some((item) => item.date > today &&
    (new Date(`${item.date}T00:00:00Z`).getUTCDay() + 6) % 7 === 0), false);
});

test("blocks ordinary users from admin routes", async (t) => {
  const { base, server } = await startApp();
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const result = await request(base, "GET", "/api/v1/admin/users");
  assert.equal(result.response.status, 403);
});

test("allows a super admin to create and deactive a facility", async (t) => {
  const { base, server, store } = await startApp();
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const adminProfile = await store.getOrCreateProfile({
    firebaseUid: "admin-firebase",
    name: "Lim Admin",
    email: "admin@example.test",
  });
  adminProfile.role = "super_admin";
  store.profiles.set(adminProfile.id, adminProfile);

  const created = await fetch(`${base}/api/v1/admin/facilities`, {
    method: "POST",
    headers: {
      Authorization: "Bearer admin",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ name: "Design Lab", latitude: 2.31, longitude: 111.81 }),
  });
  assert.equal(created.status, 201);
  const facility = await created.json();

  const updated = await fetch(`${base}/api/v1/admin/facilities/${facility.data.id}`, {
    method: "PATCH",
    headers: {
      Authorization: "Bearer admin",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ isActive: false }),
  });
  assert.equal(updated.status, 200);
  assert.equal((await updated.json()).data.isActive, false);
});
