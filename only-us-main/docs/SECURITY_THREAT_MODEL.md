# Security & Threat Model — Only Us

## 1. What Only Us protects

Only Us is a private messenger for exactly two people. The assets are:

- The couple's messages, photos, voice notes, and call history.
- Knowledge of *who* the two people are and that they talk to each
  other (metadata: who messaged when, call times).
- The surprise / gift schedule (timing should stay secret until unlock).

The promise: **nobody else — not a third user, not a stranger, not a
random Firebase account — can read or write the couple's data.**

## 2. Trust boundaries

| Party | Trusted with | NOT trusted with |
|---|---|---|
| The two partners' phones | Their own keys, their own data | Each other's passwords |
| Firebase (Google) | Storing encrypted-in-transit data, enforcing rules, delivering push | Reading message content is outside the design's control — see E2EE status below |
| The app code / this repo | Enforcing the two-person allowlist in UI | Nothing secret lives in the repo |
| Any third person / third UID | Nothing | All data, all access |

## 3. End-to-end encryption (E2EE) — honest status

**Status: design implemented with maintained libraries; full
two-device verification NOT RUN. Do NOT claim E2EE is complete.**

What that means, concretely:

- The design uses maintained, standard libraries for encryption
  (per-partner keys, encrypted message payloads). The code for it
  lives in Part B/C.
- What has **not** happened yet: a two-device verification — partner A
  sends a message, partner B receives and decrypts it, and an
  independent check confirms the ciphertext is unreadable to anyone
  holding only the Firebase data (e.g. a third UID reading the raw
  Firestore documents, or someone with the `google-services.json`).
- Until that verification runs and passes, treat the app as
  **transport-encrypted + access-controlled** (TLS to Firebase,
  Firestore rules allowing only the two UIDs), not as proven E2EE.
- Verification steps (to be run, then recorded here with date):
  1. Two provisioned devices, A and B, exchange messages.
  2. Read the raw Firestore documents as a third UID (or from the
     Firebase Console) and confirm the message bodies are ciphertext,
     not readable text.
  3. Confirm B decrypts and displays the original text.
  4. Confirm a tampered ciphertext fails to decrypt instead of
     showing garbage or crashing.
  5. Confirm key rotation / new-device flow does not lock either
     partner out of history unexpectedly (or document that it does).

## 4. Threats and mitigations

| Threat | Mitigation | Status |
|---|---|---|
| Third Firebase user reads/writes the couple's data | Firestore rules allow only the two provisioned UIDs; client allowlist mirrors it (`lib/shared/utils/allowlist.dart`) | Rules written (Part A/C); manual checklist in `test/rules/firestore_rules_test.md` — **NOT RUN yet** |
| Unauthenticated access | Rules deny all unauthenticated reads/writes; app requires sign-in | Checklist NOT RUN yet |
| Partner A forges a message as partner B | Rules require `senderUid == request.auth.uid` | Checklist item 4.1 — NOT RUN yet |
| Third UID added to the couple | Rules forbid changing `memberUids`; only two UIDs exist | Checklist item 4.3 — NOT RUN yet |
| Message shown twice (echo + server copy) | Dedup by `clientId` (`lib/shared/utils/dedup.dart`) | Unit-tested (`test/unit/message_dedup_test.dart`) — tests not yet run (no Flutter SDK in this environment) |
| Hug/heart spam floods the partner | Client throttle: max 1 per 10s, max 20/hour (`lib/shared/utils/heart_throttle.dart`); server-side limit still required | Client logic unit-tested; server limit NOT implemented/verified yet |
| Surprise read before its unlock time | Client checks `now >= unlockAt` in UTC (`lib/shared/utils/surprise_unlock.dart`); **server must enforce it too** — a client-only check can be bypassed by a modified app | Client logic unit-tested; server enforcement NOT verified yet |
| Stolen / lost phone | Revoke refresh tokens + change password in Firebase Console (see `docs/PROVISIONING.md` §6); device lock screen is the first line of defence | Process documented, not tested |
| APK decompiled, secrets extracted | No secrets in the APK: no service-account keys, no TURN passwords, no API keys in code. TURN credentials come from Remote Config / Cloud Function (see `docs/WEBRTC_TURN.md`) | By construction — verify with a release APK scan before release |
| Push notification leaks message text | FCM notifications carry minimal content (e.g. "New message from ❤️") — full text only if explicitly chosen; review before release | To verify |
| Logs leak message content | Safe logging: never log message bodies, UIDs in full, tokens, or passwords. Log event types + truncated ids only | Convention — enforce in code review |
| Man-in-the-middle on calls | WebRTC uses DTLS-SRTP; signalling goes over TLS to Firestore | By library design; not independently verified |

## 5. Keystore & signing

- The release keystore is created on the developer's Windows machine
  with `keytool` (see `README.md`). It is **never** committed to git.
- `key.properties` (keystore path + passwords) lives outside the repo
  (e.g. `C:\Users\<you>\only-us-keys\`) and is referenced by
  `android/key.properties` — which is git-ignored.
- If the keystore is lost, the app **cannot** be updated under the same
  Play Store / package identity. Back it up (encrypted) in two places.
- Debug builds use the debug keystore; never ship a debug-signed APK
  as a release.

## 6. Safe logging

- ✅ Log: "message sent", "call started", "sync completed", error
  *types* ("decrypt failed"), counts.
- ❌ Never log: message text, photo contents, voice-note transcripts,
  full UIDs (truncate to first 6 chars if an id is ever needed),
  FCM tokens, passwords, TURN credentials, key material.
- Crash reports: disable or scrub before release if the crash SDK
  would capture message content; verify what it sends.

## 7. Retention & deletion

- Messages are kept in Firestore until a partner deletes them (or the
  couple's data is deleted). There is no automatic expiry.
- Deleting the app does **not** delete the server-side history. To
  fully delete the couple's data: delete the couple document and its
  subcollections in Firestore, delete uploaded media from Storage,
  and revoke both users' refresh tokens.
- If the relationship ends, either partner can ask for full deletion —
  do it from the Firebase Console, and confirm in writing that it is
  done.

## 8. Rate limiting

- Client-side: hearts max 1 per 10s and max 20/hour
  (`lib/shared/utils/heart_throttle.dart`, unit-tested).
- Server-side: Firestore rules / Cloud Functions should enforce the
  same caps — client checks alone can be bypassed by a modified app.
  **Server-side rate limiting is not yet implemented or verified.**
- Login: Firebase Auth's built-in protections apply; add App Check
  before public release to reduce automated abuse.

## 9. What is NOT in scope

- No analytics, no ads, no third-party trackers in the app.
- No iOS build (Android only).
- No Play Store listing yet (sideloaded APK / internal distribution).
- No backup of messages outside Firebase.
