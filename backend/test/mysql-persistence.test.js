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
