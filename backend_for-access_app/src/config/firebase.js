import admin from "firebase-admin";
import fs from "fs";

export function initFirebaseAdmin() {
  if (admin.apps.length > 0) {
    return;
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw new Error("FIREBASE_PROJECT_ID is required");
  }

  const rawServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (rawServiceAccount) {
    const credentials = JSON.parse(rawServiceAccount);
    admin.initializeApp({
      credential: admin.credential.cert(credentials),
      projectId,
    });
    return;
  }

  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (credentialsPath && fs.existsSync(credentialsPath)) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId,
    });
    return;
  }

  // Fallback mode: allows verifyIdToken() signature checks without crashing
  // when a service-account file is not mounted in Docker.
  admin.initializeApp({ projectId });
}

export function getFirebaseAuth() {
  return admin.auth();
}

export function hasFirebaseAdminCredentials() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return true;
  }
  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  return Boolean(credentialsPath && fs.existsSync(credentialsPath));
}
