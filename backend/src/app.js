const express = require("express");
const { mountDeadlines, fail } = require("./deadlines");
const services = require("./services");

function createApp(dependencies = services) {
  const app = express();
  app.disable("x-powered-by");
  app.use(express.json());
  app.get("/health", (_req, res) => res.json({ status: "ok" }));
  mountDeadlines(app, dependencies);
  app.use((error, _req, res, _next) => {
    if (error.type === "entity.parse.failed") return fail(res, 400, "INVALID_JSON", "Invalid JSON body.");
    if (error.type === "entity.too.large") return fail(res, 413, "BODY_TOO_LARGE", "Request body too large.");
    console.error("Planner request failed", error.code || error.name);
    return fail(res, 500, "INTERNAL_ERROR", "Unable to complete the request.");
  });
  return app;
}

module.exports = createApp();
module.exports.createApp = createApp;
