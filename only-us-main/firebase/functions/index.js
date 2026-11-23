/**
 * Only Us — Cloud Functions.
 *
 * revealSurprise: the ONLY way a sealed surprise is revealed.
 * Server-enforced unlock: the function checks the server time
 * (admin.firestore Timestamp.now()) against unlockAt, checks the
 * caller is one of the two couple members, and only then returns
 * the ciphertext for the client to decrypt locally with the couple
 * key. It never returns content before unlockAt, and clients cannot
 * set revealed:true themselves (Firestore rules deny it).
 *
 * Deploy: firebase deploy --only functions,firestore:rules,storage
 * after replacing PARTNER_A/B placeholders in the rules.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const PARTNER_UIDS = new Set([
  "mzNOSMi0bgU5QNzyy29UKBEyOhX2",
  "SkZx6Wh7cFVj1XuDdM4WIlx3JxB2",
]);

exports.revealSurprise = functions.https.onCall(async (data, context) => {
  if (!context.auth || !PARTNER_UIDS.has(context.auth.uid)) {
    throw new functions.https.HttpsError("permission-denied", "Not allowed.");
  }
  const coupleId = data && data.coupleId;
  const surpriseId = data && data.surpriseId;
  if (typeof coupleId !== "string" || typeof surpriseId !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "Bad ids.");
  }
  const couple = await db.collection("couples").doc(coupleId).get();
  if (!couple.exists) {
    throw new functions.https.HttpsError("not-found", "No such couple.");
  }
  const members = couple.get("memberUids") || [];
  if (!members.includes(context.auth.uid)) {
    throw new functions.https.HttpsError("permission-denied", "Not a member.");
  }
  const snap = await db.collection("surprises").doc(surpriseId).get();
  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "No such surprise.");
  }
  const surprise = snap.data();
  if (surprise.coupleId !== coupleId) {
    throw new functions.https.HttpsError("permission-denied", "Wrong couple.");
  }
  const unlockAt = surprise.unlockAt && surprise.unlockAt.toDate
    ? surprise.unlockAt.toDate()
    : null;
  if (!unlockAt || Date.now() < unlockAt.getTime()) {
    // Fail closed: locked, no content returned.
    return { revealed: false, locked: true };
  }
  // Mark revealed server-side (clients cannot do this themselves).
  await snap.ref.update({ sealed: false, revealedAt: admin.firestore.FieldValue.serverTimestamp() });
  return { revealed: true, ciphertext: surprise.ciphertext || null };
});
