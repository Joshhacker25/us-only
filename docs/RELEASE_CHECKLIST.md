# Release Checklist — Only Us

Check every box before calling a build a release. If a box cannot be
checked, write the reason next to it and do not ship until it is
resolved or explicitly accepted by both partners.

## 1. Provisioning

- [ ] Two Firebase Auth users created (see `docs/PROVISIONING.md`)
- [ ] Real UIDs replace the placeholders in `lib/shared/utils/allowlist.dart`
- [ ] Real UIDs replace the placeholders in `firebase/firestore.rules`
- [ ] Firestore rules deployed (`firebase deploy --only firestore:rules`)
- [ ] `google-services.json` in `android/app/` (NOT committed to git)
- [ ] Firestore indexes deployed if the app needs them
      (`firebase deploy --only firestore:indexes`)

## 2. Code quality

- [ ] `flutter analyze` — zero errors (warnings reviewed)
- [ ] `flutter test` — all unit + widget tests pass
- [ ] No `TODO` / `FIXME` left that affects behaviour
- [ ] No secrets in code: search the repo for `password`, `secret`,
      `api_key`, `private_key`, `BEGIN` — nothing real should appear
- [ ] No `print` of message content, tokens, or UIDs left in the code
- [ ] `pubspec.yaml` version bumped (`version: x.y.z+n`)

## 3. Security tests

- [ ] `test/rules/firestore_rules_test.md` — every check run and PASS
      (third UID denied, unauthenticated denied, partner A/B allowed,
      forgery denied)
- [ ] E2EE two-device verification run (see
      `docs/SECURITY_THREAT_MODEL.md` §3) — or the release notes state
      clearly that E2EE is **not** verified
- [ ] Surprise server-enforced unlock verified (not just the
      client-side check)
- [ ] Server-side heart rate limiting verified (not just client-side)
- [ ] Release APK scanned for embedded secrets (strings check)

## 4. Two-device tests (both partners' real phones)

- [ ] Both partners sign in; each sees the other (and nobody else)
- [ ] Chat: send text both ways; one copy each, in order
- [ ] Chat: photo + voice note both ways
- [ ] Love tab: hug / kiss / heart arrives within ~5s; double-tap is
      throttled (max 1 per 10s)
- [ ] Surprise: locked before `unlockAt`, visible at/after it
- [ ] Relationship day counter shows the same day number on both
      phones (same-day = day 1)
- [ ] Calls: audio call both directions, same Wi-Fi
- [ ] Calls: audio + video, mobile data ↔ Wi-Fi (TURN if provisioned)
- [ ] Calls: incoming call rings while the app is backgrounded
- [ ] Calls: end call from each side; both phones return cleanly
- [ ] Offline: airplane mode → send message → back online → message
      arrives once, in order
- [ ] Nearby: pair the two phones, send a message offline, confirm
      delivery + sync (see `docs/NEARBY.md`)

## 5. Widget test (home-screen love widget)

- [ ] Widget added to the home screen on a real phone
- [ ] Widget shows the current day count / latest love note
- [ ] Tapping the widget opens the app (to the Love tab)
- [ ] Widget updates within the platform limits (see
      `KNOWN_LIMITATIONS.md` — widgets do not update instantly)

## 6. Permissions test

- [ ] Fresh install: grant/deny each permission and confirm the app
      explains itself (camera, mic, notifications, Bluetooth/location
      for Nearby)
- [ ] Denying notifications still lets chat work (just silently)
- [ ] Denying mic/camera blocks calls with a clear message, not a crash

## 7. Signing & build

- [ ] Release keystore exists on the Windows build machine (see
      `README.md` — keystore is NOT in the repo)
- [ ] `android/key.properties` points at the keystore (git-ignored)
- [ ] `flutter build apk --release` succeeds
- [ ] APK installs on a phone that never had the app (clean install)
- [ ] APK upgrades over the previous release without losing login/data
- [ ] App icon + name show correctly on the home screen

## 8. Release notes

- [ ] Version number + build date recorded
- [ ] Known limitations listed for both partners (see
      `KNOWN_LIMITATIONS.md`)
- [ ] Rollback plan: previous APK kept, and the steps to re-install it
      written down
- [ ] Both partners confirm they have the release APK and can sign in

## Sign-off

| Field | Value |
|---|---|
| Version | ________ |
| Date | ________ |
| Built by | ________ |
| Tested on | Device A: ________ / Device B: ________ |
| Result | ☐ RELEASE — ☐ NOT READY (reasons below) |

Reasons / open items:

- (none recorded yet)
