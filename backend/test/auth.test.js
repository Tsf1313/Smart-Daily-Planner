const assert = require("node:assert/strict");
const Module = require("node:module");
const { test } = require("node:test");

const calls = [];
const apps = [];
const appApi = {
  applicationDefault() {
    calls.push(["applicationDefault"]);
    return "application-default-credential";
  },
  cert(serviceAccount) {
    calls.push(["cert", serviceAccount]);
    return "service-account-credential";
  },
  getApps() {
    calls.push(["getApps"]);
    return apps;
  },
  initializeApp(options) {
    calls.push(["initializeApp", options]);
    const app = { initialized: true };
    apps.push(app);
    return app;
  },
};
const authApi = {
  getAuth(app) {
    calls.push(["getAuth", app]);
    return {
      async verifyIdToken(token) {
        calls.push(["verifyIdToken", token]);
        return { uid: "student-uid", email: "student@example.test", name: "Student Name" };
      },
    };
  },
};

const originalLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === "firebase-admin/app") return appApi;
  if (request === "firebase-admin/auth") return authApi;
  return originalLoad.call(this, request, parent, isMain);
};
let createFirebaseVerifier;
try {
  ({ createFirebaseVerifier } = require("../src/auth"));
} finally {
  Module._load = originalLoad;
}

test("FIREBASE_SERVICE_ACCOUNT alone configures the modular Firebase verifier", async (t) => {
  const oldProjectId = process.env.FIREBASE_PROJECT_ID;
  const oldServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
  const oldCredentials = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  t.after(() => {
    if (oldProjectId === undefined) delete process.env.FIREBASE_PROJECT_ID;
    else process.env.FIREBASE_PROJECT_ID = oldProjectId;
    if (oldServiceAccount === undefined) delete process.env.FIREBASE_SERVICE_ACCOUNT;
    else process.env.FIREBASE_SERVICE_ACCOUNT = oldServiceAccount;
    if (oldCredentials === undefined) delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
    else process.env.GOOGLE_APPLICATION_CREDENTIALS = oldCredentials;
  });

  delete process.env.FIREBASE_PROJECT_ID;
  delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
  process.env.FIREBASE_SERVICE_ACCOUNT = JSON.stringify({ projectId: "test-project" });
  apps.length = 0;
  calls.length = 0;

  const verify = createFirebaseVerifier();
  assert.deepEqual(await verify("student-token"), {
    firebaseUid: "student-uid",
    email: "student@example.test",
    name: "Student Name",
  });
  assert.ok(calls.some(([name]) => name === "getApps"));
  assert.ok(calls.some(([name]) => name === "cert"));
  assert.ok(calls.some(([name]) => name === "initializeApp"));
  assert.ok(calls.some(([name]) => name === "getAuth"));
  assert.ok(calls.some(([name, token]) => name === "verifyIdToken" && token === "student-token"));

  delete process.env.FIREBASE_SERVICE_ACCOUNT;
  process.env.GOOGLE_APPLICATION_CREDENTIALS = "credentials.json";
  apps.length = 0;
  calls.length = 0;
  createFirebaseVerifier();
  assert.ok(calls.some(([name]) => name === "applicationDefault"));
  assert.ok(calls.some(([name]) => name === "initializeApp"));

  const existingApp = { initialized: true };
  apps.splice(0, apps.length, existingApp);
  calls.length = 0;
  createFirebaseVerifier();
  assert.ok(calls.some(([name]) => name === "getApps"));
  assert.equal(calls.some(([name]) => name === "initializeApp"), false);
});
