function createFirebaseVerifier() {
  if (!process.env.FIREBASE_PROJECT_ID && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return async () => {
      throw new Error("Firebase Admin is not configured.");
    };
  }
  const admin = require("firebase-admin");
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: process.env.FIREBASE_SERVICE_ACCOUNT
        ? admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT))
        : admin.credential.applicationDefault(),
    });
  }
  return async (token) => {
    const decoded = await admin.auth().verifyIdToken(token);
    return {
      firebaseUid: decoded.uid,
      email: decoded.email || "",
      name: decoded.name || decoded.email || "Student",
    };
  };
}

module.exports = { createFirebaseVerifier };
