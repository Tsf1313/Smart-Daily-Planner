const assert = require("node:assert/strict");
const { test } = require("node:test");
const { createApp } = require("../src/app");

test("deadline HTTP contract", async (t) => {
  const rows = [];
  const app = createApp({
    async verifyUser(token) {
      if (["alice", "bob"].includes(token)) return token;
      throw Object.assign(new Error(), { code: "auth/invalid-id-token" });
    },
    store: {
      async create(owner, entry) { rows.push({ owner, entry }); },
      async list(owner, from, to) {
        return rows.filter(row => row.owner === owner &&
          (!from || row.entry.dueDate >= from) && (!to || row.entry.dueDate <= to))
          .map(row => row.entry);
      },
    },
  });
  const server = app.listen(0, "127.0.0.1");
  await new Promise(resolve => server.once("listening", resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = "http://127.0.0.1:" + server.address().port + "/api/v1/entries";
  const body = { kind: "deadline", title: "Submit MAD report", dueDate: "2026-11-30" };
  const get = (token, query = "") => fetch(url + query, { headers: { Authorization: "Bearer " + token } });
  const post = (payload) => fetch(url, {
    method: "POST", headers: { Authorization: "Bearer alice", "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  await t.test("requires a signed-in student", async () => {
    assert.equal((await fetch(url)).status, 401);
    assert.equal((await get("invalid")).status, 401);
  });
  await t.test("rejects impossible dates, blank titles and client-selected owners", async () => {
    for (const change of [{ dueDate: "2026-02-29" }, { title: " " }, { ownerId: "bob" }]) {
      assert.equal((await post({ ...body, ...change })).status, 400);
    }
    assert.equal(rows.length, 0);
  });
  await t.test("creates a dated entry and lists it only for its owner", async () => {
    const result = await post(body);
    assert.equal(result.status, 201);
    const { data } = await result.json();
    assert.ok(data.id);
    assert.deepEqual(data, { ...body, id: data.id });
    assert.deepEqual(await (await get("alice", "?from=2026-11-30&to=2026-11-30")).json(), { data: [data] });
    assert.deepEqual(await (await get("bob")).json(), { data: [] });
  });
  await t.test("handles out-of-range and reversed date filters", async () => {
    assert.deepEqual(await (await get("alice", "?to=2026-11-29")).json(), { data: [] });
    assert.equal((await get("alice", "?from=2026-12-01&to=2026-11-01")).status, 400);
  });
});
