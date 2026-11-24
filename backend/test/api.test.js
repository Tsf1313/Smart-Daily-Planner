const assert = require("node:assert/strict");
const { test } = require("node:test");
const { createApp } = require("../src/app");
const { MemoryStore } = require("../src/store/memory");

async function startApp(store = new MemoryStore()) {
  const app = createApp({
    store,
    verifyFirebaseToken: async (token) => {
      if (token === "bad") throw new Error("invalid");
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

test("profile requires Firebase authentication", async (t) => {
  const { base, server } = await startApp();
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const missing = await fetch(`${base}/api/v1/me`);
  assert.equal(missing.status, 401);
  const bad = await fetch(`${base}/api/v1/me`, { headers: { Authorization: "Bearer bad" } });
  assert.equal(bad.status, 401);
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
