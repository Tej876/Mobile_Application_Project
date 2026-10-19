const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

let firebaseInitialized = false;

function initFirebase() {
  if (firebaseInitialized || admin.apps.length > 0) {
    return admin;
  }

  const keyPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY || './serviceAccountKey.json';
  const resolvedPath = path.resolve(process.cwd(), keyPath);

  if (fs.existsSync(resolvedPath)) {
    try {
      const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.project_id || process.env.FIREBASE_PROJECT_ID,
      });
      firebaseInitialized = true;
      console.log('✅ [Firebase Admin] Initialized with service account key');
      return admin;
    } catch (err) {
      console.warn(`⚠️ [Firebase Admin] Failed to parse serviceAccountKey: ${err.message}`);
    }
  }

  // Fallback to project ID or default application credentials
  const projectId = process.env.FIREBASE_PROJECT_ID || 'queueless-12345';
  try {
    admin.initializeApp({
      projectId,
    });
    firebaseInitialized = true;
    console.log(`ℹ️ [Firebase Admin] Initialized with Project ID: ${projectId}`);
  } catch (err) {
    console.warn(`⚠️ [Firebase Admin] Initialization warning: ${err.message}`);
  }

  return admin;
}

module.exports = { initFirebase, admin };
