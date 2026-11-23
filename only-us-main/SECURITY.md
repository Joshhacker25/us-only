# Security Policy — Only Us

## Reporting a vulnerability

If you find a security problem in Only Us, **do not open a public
issue and do not post about it**. Tell one of the two partners
directly and privately (in the app, or whatever private channel you
normally use with them), with:

1. What you found and where (file, screen, or steps to reproduce).
2. What an attacker could do with it (read messages? impersonate a
   partner? bypass the allowlist?).
3. Whether you think it is already being exploited.

You will get a reply confirming receipt, and the partners will decide
the fix and the timing. There is no bug bounty — this is a private
app for two people.

## Provisioning summary

Only Us is for exactly **two** authorised people. The security of
the whole app rests on provisioning being done correctly:

- Two Firebase Auth users are created — one per partner — with strong
  passwords kept in a password manager, never in code or git.
- Their real UIDs replace the placeholders in
  `lib/shared/utils/allowlist.dart` and in `firebase/firestore.rules`.
- Firestore rules allow **only** those two UIDs. A third UID and
  unauthenticated access are denied everywhere.
- No service-account keys, Admin SDK credentials, TURN passwords, or
  other secrets are ever committed to the repo or embedded in the APK.
  TURN credentials are delivered via Firebase Remote Config or a
  Cloud Function (see `docs/WEBRTC_TURN.md`).
- Password recovery is via Firebase Auth password reset only. There
  is no master password and no backdoor.

Full steps: `docs/PROVISIONING.md`. Full threat model (including the
honest E2EE status — designed, **not fully verified**):
`docs/SECURITY_THREAT_MODEL.md`. Access-control checklist:
`test/rules/firestore_rules_test.md`.

## What to do if a device is lost or an account is compromised

1. In Firebase Console → Authentication → Users, revoke the affected
   user's refresh tokens and change their password.
2. If the couple's data must be locked down immediately, remove that
   UID from the deployed Firestore rules and redeploy.
3. For full deletion, follow the retention/deletion steps in
   `docs/SECURITY_THREAT_MODEL.md` §7.
