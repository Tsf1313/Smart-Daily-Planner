const { applicationDefault, cert, getApps, initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

function createFirebaseVerifier() {
  if (
    !process.env.FIREBASE_PROJECT_ID &&
    !process.env.FIREBASE_SERVICE_ACCOUNT &&
    !process.env.GOOGLE_APPLICATION_CREDENTIALS
  ) {
    return async () => {
      throw new Error("Firebase Admin is not configured.");
    };
  }
  const app = getApps()[0] || initializeApp({
    credential: process.env.FIREBASE_SERVICE_ACCOUNT
      ? cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT))
      : applicationDefault(),
  });
  return async (token) => {
    const decoded = await getAuth(app).verifyIdToken(token);
    return {
      firebaseUid: decoded.uid,
      email: decoded.email || "",
      name: decoded.name || decoded.email || "Student",
    };
  };
}

module.exports = { createFirebaseVerifier };
