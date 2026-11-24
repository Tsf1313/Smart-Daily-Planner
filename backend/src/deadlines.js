const { randomUUID } = require("node:crypto");

function validDate(value) {
  if (typeof value !== "string" || !/^[1-9]\d{3}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(value + "T00:00:00Z");
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function fail(res, status, code, message) {
  return res.status(status).json({ error: { code, message } });
}

function mountDeadlines(app, { verifyUser, store }) {
  const path = "/api/v1/entries";
  app.use(path, async (req, res, next) => {
    const token = /^Bearer ([^\s]+)$/i.exec(req.get("authorization") || "");
    if (!token) return fail(res, 401, "UNAUTHORIZED", "Sign in to access your planner.");
    try {
      req.ownerUid = await verifyUser(token[1]);
      next();
    } catch (error) {
      if (error.code === "auth/user-disabled") return fail(res, 403, "SUSPENDED", "Account disabled.");
      if (["auth/argument-error", "auth/id-token-expired", "auth/id-token-revoked",
           "auth/invalid-id-token", "auth/user-not-found"].includes(error.code)) {
        return fail(res, 401, "UNAUTHORIZED", "Sign in again.");
      }
      next(error);
    }
  });

  app.post(path, async (req, res) => {
    const body = req.body;
    if (body?.kind !== "deadline" || typeof body.title !== "string" ||
        !body.title.trim() || [...body.title.trim()].length > 200 || !validDate(body.dueDate) ||
        Object.keys(body).some(key => !["title", "kind", "dueDate"].includes(key))) {
      return fail(res, 400, "INVALID_ENTRY", "Supply kind deadline, a title of 1–200 characters and a valid YYYY-MM-DD dueDate.");
    }
    const entry = { id: randomUUID(), kind: "deadline", title: body.title.trim(), dueDate: body.dueDate };
    await store.create(req.ownerUid, entry);
    res.status(201).json({ data: entry });
  });

  app.get(path, async (req, res) => {
    const { from, to } = req.query;
    if (Object.keys(req.query).some(key => !["from", "to"].includes(key)) ||
        (from !== undefined && !validDate(from)) || (to !== undefined && !validDate(to)) ||
        (from && to && from > to)) {
      return fail(res, 400, "INVALID_RANGE", "Use optional inclusive YYYY-MM-DD bounds, from through to.");
    }
    res.json({ data: await store.list(req.ownerUid, from, to) });
  });
}

module.exports = { mountDeadlines, fail };
