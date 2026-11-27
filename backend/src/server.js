require("dotenv").config();
const { createApp } = require("./app");
const { createStore } = require("./services");

const port = Number(process.env.PORT || 3000);

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error("PORT must be an integer between 1 and 65535.");
}

async function start() {
  const store = createStore();
  try {
    await store.ping();
  } catch (error) {
    console.error(`MySQL connection failed; backend was not started: ${error.message}`);
    try {
      await store.close();
    } catch (closeError) {
      console.error(`MySQL pool cleanup failed: ${closeError.message}`);
    }
    process.exitCode = 1;
    return;
  }

  const server = createApp({ store }).listen(port, () => {
    console.log(`Backend listening on port ${port}.`);
  });
  server.on("error", (error) => {
    console.error("Backend server failed to start:", error);
    process.exitCode = 1;
  });
  server.on("close", () => {
    store.close().catch((error) => console.error(`MySQL pool cleanup failed: ${error.message}`));
  });
}

start().catch((error) => {
  console.error("Backend server failed to start:", error.message);
  process.exitCode = 1;
});
