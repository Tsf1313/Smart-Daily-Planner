const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const { test } = require("node:test");
const mysql = require("mysql2/promise");
const { createApp } = require("../src/app");
const { MysqlStore } = require("../src/store/mysql");

test("MySQL deadlines survive an Express restart and remain owner-scoped", {
  skip: !process.env.MYSQL_TEST_URL,
}, async (t) => {
  const pool = mysql.createPool(process.env.MYSQL_TEST_URL);
  const store = new MysqlStore(pool);
  const suffix = randomUUID();
  const uidA = `restart-test-a-${suffix}`;
  const uidB = `restart-test-b-${suffix}`;
  const servers = [];
  const start = async () => {
    const app = createApp({
      store,
      verifyFirebaseToken: async (token) => {
        if (token === "student-a") return { firebaseUid: uidA, name: "Student A", email: "" };
        if (token === "student-b") return { firebaseUid: uidB, name: "Student B", email: "" };
        throw new Error("Invalid test token.");
      },
    });
    const server = app.listen(0, "127.0.0.1");
    servers.push(server);
    await new Promise((resolve) => server.once("listening", resolve));
    return `http://127.0.0.1:${server.address().port}/api/v1/entries`;
  };
  const closeServers = async () => {
    await Promise.all(servers.filter((server) => server.listening).map((server) =>
      new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve())),
    ));
  };
  t.after(async () => {
    await closeServers();
    await pool.execute(
      `DELETE e FROM entries e JOIN users u ON u.id = e.owner_id
       WHERE u.firebase_uid IN (?, ?)`,
      [uidA, uidB],
    );
    await pool.execute("DELETE FROM users WHERE firebase_uid IN (?, ?)", [uidA, uidB]);
    await store.close();
  });

  const firstUrl = await start();
  const created = await fetch(firstUrl, {
    method: "POST",
    headers: { Authorization: "Bearer student-a", "Content-Type": "application/json" },
    body: JSON.stringify({ kind: "deadline", title: "Persistent report", dueDate: "2026-11-30" }),
  });
  assert.equal(created.status, 201);
  const createdData = (await created.json()).data;
  await closeServers();

  const restartedUrl = await start();
  const studentA = await fetch(restartedUrl, { headers: { Authorization: "Bearer student-a" } });
  assert.equal(studentA.status, 200);
  assert.deepEqual(await studentA.json(), {
    data: [{ id: createdData.id, title: "Persistent report", dueDate: "2026-11-30" }],
  });

  const studentB = await fetch(restartedUrl, { headers: { Authorization: "Bearer student-b" } });
  assert.equal(studentB.status, 200);
  assert.deepEqual(await studentB.json(), { data: [] });
});

test("MySQL routine edits remove obsolete future occurrences and preserve completed history", {
  skip: !process.env.MYSQL_TEST_URL,
}, async (t) => {
  const pool = mysql.createPool(process.env.MYSQL_TEST_URL);
  const store = new MysqlStore(pool);
  const uid = `routine-edit-test-${randomUUID()}`;
  let ownerId;
  t.after(async () => {
    if (ownerId) {
      await pool.execute("DELETE FROM entries WHERE owner_id = ?", [ownerId]);
      await pool.execute("DELETE FROM users WHERE id = ?", [ownerId]);
    }
    await store.close();
  });

  const profile = await store.getOrCreateProfile({
    firebaseUid: uid,
    name: "Routine Edit Test",
    email: "",
  });
  ownerId = profile.id;
  const today = new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const addDays = (date, days) => {
    const result = new Date(`${date}T00:00:00Z`);
    result.setUTCDate(result.getUTCDate() + days);
    return result.toISOString().slice(0, 10);
  };
  const todayWeekday = (new Date(`${today}T00:00:00Z`).getUTCDay() + 6) % 7;
  const startDate = addDays(today, -(todayWeekday + 7));
  const repeatUntil = addDays(startDate, 28);
  const routine = await store.createEntry(ownerId, {
    kind: "routine",
    title: "Routine edit test",
    startDate,
    startTime: "20:00",
    endTime: "21:00",
    repeat: "weekly",
    weekdays: [1],
    repeatUntil,
  });
  const before = await store.listOccurrences(ownerId, {
    from: `${startDate}T00:00:00Z`,
    to: `${addDays(repeatUntil, 1)}T00:00:00Z`,
  });
  const completedMonday = before.find((item) => item.date === startDate);
  assert.ok(completedMonday);
  await store.setOccurrenceCompletion(ownerId, completedMonday.id, true);
  const pastOccurrences = (await store.listOccurrences(ownerId, {
    from: `${startDate}T00:00:00Z`,
    to: `${addDays(repeatUntil, 1)}T00:00:00Z`,
  })).filter((item) => item.date < today);
  await store.updateEntry(ownerId, routine.id, { weekdays: [3] });
  const after = await store.listOccurrences(ownerId, {
    from: `${startDate}T00:00:00Z`,
    to: `${addDays(repeatUntil, 1)}T00:00:00Z`,
  });

  for (const pastOccurrence of pastOccurrences) {
    assert.deepEqual(after.find((item) => item.id === pastOccurrence.id), pastOccurrence);
  }
  assert.equal(after.find((item) => item.id === completedMonday.id)?.isCompleted, true);
  assert.equal(after.some((item) => item.date < today &&
    (new Date(`${item.date}T00:00:00Z`).getUTCDay() + 6) % 7 === 2), false);
  assert.equal(after.some((item) => item.date > today &&
    (new Date(`${item.date}T00:00:00Z`).getUTCDay() + 6) % 7 === 0), false);
  assert.ok(after.some((item) => item.date > today &&
    (new Date(`${item.date}T00:00:00Z`).getUTCDay() + 6) % 7 === 2));
});
