# Known Limitations — Only Us

An honest list of what does not work yet, is not verified, or is
limited by the platform. Nothing here is a secret — both partners
should know these before relying on the app.

## Security & encryption

- **E2EE is NOT fully verified.** AES-256-GCM encryption is
  implemented with maintained libraries (`encrypt` package, Keystore-
  backed key), but the full two-device verification (partner A sends,
  partner B decrypts, raw Firestore data confirmed unreadable to a
  third party) has **not run**. Until it does, treat the app as
  transport-encrypted + access-controlled (TLS + Firestore rules for
  the two UIDs only), not as proven end-to-end encrypted.
  See `docs/SECURITY_THREAT_MODEL.md` §3.
- **Firestore rules checklist NOT RUN.** The manual access-control
  tests in `test/rules/firestore_rules_test.md` (third UID denied,
  unauthenticated denied, forgery denied) have not been executed
  against a live ruleset yet.
- **Surprise unlock: server function written, NOT deployed/tested.**
  `firebase/functions/index.js` implements `revealSurprise` (server
  time check, fails closed, clients cannot set revealed:true — rules
  deny it). It has not been deployed or tested against a live project,
  so do not rely on it until the deploy + test in
  `docs/RELEASE_CHECKLIST.md` passes.
- **Server-side rate limiting NOT implemented/verified yet.** Hearts
  are throttled on the client (max 1 per 10s, max 20/hour), but a
  modified app could bypass the client check.

## Calling

- **TURN is NOT provisioned.** Calls use STUN only, which works on
  most home networks but can fail on restrictive networks (some mobile
  carriers, symmetric NAT, workplaces/schools). Symptom: the call
  rings but there is no audio/video. Provision TURN per
  `docs/WEBRTC_TURN.md`.
- **FCM / background limits.** An incoming call may not ring reliably
  while the app is backgrounded or the phone is locked, especially on
  phones with aggressive battery optimisation (some Xiaomi, Huawei,
  Samsung, and other OEMs). Both partners may need to disable battery
  optimisation for Only Us.
- **No call recording.** Calls are not recorded, by design.

## Nearby Connections

- **Bluetooth-only HD video is NOT supported.** Video calls need
  Wi-Fi or mobile data; Bluetooth does not have the bandwidth.
- **Long-distance offline calls are NOT supported.** Nearby works
  only within radio range (same room/house). Different cities need
  the internet.
- **Large videos offline are NOT supported** — small photos only.
  Large videos wait for Wi-Fi and the normal upload path.
- **Location must be on** for discovery on many Android versions,
  even though the app never uses or stores location.

## Home-screen widget

- **Widget updates are limited by Android.** The love widget does not
  update instantly — Android throttles widget refreshes (typically
  every ~30 minutes at best, plus updates on tap/open). Do not expect
  a hug to appear on the widget the same second it is sent.

## Platform & distribution

- **Android only.** No iOS build.
- **No Play Store listing.** The app is distributed as a sideloaded
  release APK. Updates are manual — both partners must install each
  new APK.
- **No analytics, no crash reporting by default.** If a crash SDK is
  added later, it must be checked so it never captures message content.
- **Tests: unit + widget tests PASSED here (2026-11-23).**
  `flutter test` — all 70 tests passed; `flutter analyze` — 0 errors
  (38 info/warning items, mostly deprecated `withOpacity` /
  `activeColor` uses). No APK was built here (no Android SDK, no
  `google-services.json`). The integration test
  (`integration_test/app_test.dart`) is skipped on purpose — it needs
  two real devices and a provisioned Firebase project.

## Provisioning

- The app ships with **placeholder UIDs** (`PARTNER_A_UID_PLACEHOLDER`,
  `PARTNER_B_UID_PLACEHOLDER`). Until provisioning replaces them with
  the two real Firebase Auth UIDs (`docs/PROVISIONING.md`), the app
  must not be used for real messages.
- `google-services.json` is **not included** in the repo and must be
  added per `docs/PROVISIONING.md`.
