# Provisioning Guide — Only Us (exactly two users)

This guide sets up Only Us for exactly **two** people. Nothing here
involves real secrets: there are no passwords, API keys, or
service-account keys in this document or in the app code. Anything that
looks like a secret belongs in Firebase Console / your password
manager, never in git.

## 1. Create the Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/) and
   create a project (e.g. `only-us`).
2. Add an **Android app** with the package name from
   `android/app/build.gradle` (Part A) — e.g. `com.onlyus.app`.
   Confirm the exact package name in the project before this step.
3. Download `google-services.json` and place it at
   `android/app/google-services.json`. **It is NOT in this repo.**
   Add it to `.gitignore` if it is not already there, and share it with
   your partner only over a private channel — never post it publicly.
4. In Firebase Console, enable:
   - **Authentication → Email/Password** sign-in method.
   - **Cloud Firestore** (production mode, locked down — rules below).
   - **Cloud Messaging** (for hug/heart notifications) — optional at
     first, required for background alerts.

## 2. Create the two users

Create exactly two Firebase Auth users — one per partner. Do this in
Firebase Console → Authentication → Users → Add user, or with the
Firebase Admin SDK from your own machine (never from the app).

| Partner | Email | Password |
|---|---|---|
| A | `partner-a@example.com` (replace with the real address) | Choose a strong password, store it in a password manager |
| B | `partner-b@example.com` (replace with the real address) | Choose a strong password, store it in a password manager |

Rules for the passwords:

- Each partner picks their own password. Nobody else should know it.
- Passwords are **never** written in code, in docs, in chat logs, or in
  git. If a password ever leaks, change it immediately in Firebase
  Console.
- Use a password manager. Do not reuse a password from another service.

## 3. Get the two UIDs

1. In Firebase Console → Authentication → Users, copy the **User UID**
   for partner A and for partner B. A UID looks like a random string,
   e.g. `XyZ123abcDEF456...`.
2. Record them privately (password manager secure note), for example:

   - `PARTNER_A_UID = <paste real UID A here — in your own notes, not in git>`
   - `PARTNER_B_UID = <paste real UID B here — in your own notes, not in git>`

UIDs are identifiers, not secrets — but treat them as private anyway:
only these two UIDs may ever access the app's data.

## 4. Replace the placeholder UIDs

Replace the placeholders in **all** of these places with the real UIDs:

1. `lib/shared/utils/allowlist.dart` — replace
   `kPartnerAUidPlaceholder` / `kPartnerBUidPlaceholder` with the real
   UIDs (or, preferably, load them from a config that is not committed —
   see step 5).
2. `firebase/firestore.rules` — replace the placeholder UID checks with
   the real UIDs. The rules must allow **only** these two UIDs.
3. Any seed / setup script that creates the couple document — the
   couple doc's `memberUids` must be exactly `[UID_A, UID_B]`.

Then run the access-control checklist in
`test/rules/firestore_rules_test.md` — including the third-UID-denied
and unauthenticated-denied checks — before the app is used for real
messages.

## 5. Where the UIDs live (and where they must NOT live)

- ✅ In Firestore Security Rules (deployed from `firebase/`).
- ✅ In Firebase Remote Config, if you want to change them without a
  release (read them at startup, cache them, and still enforce in
  rules — client-side checks are UI only).
- ❌ Never hard-code real UIDs in a public repo if you can avoid it;
  placeholders are in the code until provisioning, and the real values
  go in via the steps above.
- ❌ **Never** embed service-account keys, Admin SDK credentials, or
  any `*.json` private key in the app or the repo. The Admin SDK runs
  only on a machine you control, never inside the APK.

## 6. Recovery

- **Forgot password:** use Firebase Auth password reset — in the app's
  login screen ("Forgot password") or Firebase Console → Authentication
  → Users → (user) → Reset password. The reset email goes to that
  partner's email address. There is no master password and no backdoor.
- **Lost access to the email account:** that partner must recover their
  email first; Firebase cannot reset a password to a different address.
- **One partner leaves / a device is lost:** sign out everywhere from
  Firebase Console → Authentication → Users → (user) → "Revoke refresh
  tokens", change that user's password, and — if the couple is ending —
  delete the couple's Firestore data (see retention in
  `docs/SECURITY_THREAT_MODEL.md`). Removing a UID from the rules
  immediately blocks that account.
- **Adding a third person is NOT supported.** Only Us is built for two.
  Do not add a third UID to the rules — it would break the app's core
  promise. If a third person needs access, that is a different app.

## 7. Provisioning checklist

- [ ] Firebase project created, Android app registered
- [ ] `google-services.json` placed in `android/app/` (not committed)
- [ ] Email/Password auth enabled
- [ ] Two Auth users created, strong passwords in a password manager
- [ ] Both UIDs copied and recorded privately
- [ ] Placeholders replaced in `allowlist.dart` and `firestore.rules`
- [ ] Rules deployed (`firebase deploy --only firestore:rules`)
- [ ] `test/rules/firestore_rules_test.md` run — all boxes checked
- [ ] Both partners signed in on their own devices and see each other
