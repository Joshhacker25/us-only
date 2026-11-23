/// Two-person allowlist — pure functions, no Flutter imports.
///
/// Only Us is a private messenger for exactly **two** authorized people.
/// Every other UID — including any third Firebase Auth user, and any
/// unauthenticated caller — is denied. The real enforcement lives in
/// Firestore Security Rules and in the provisioning step (see
/// `docs/PROVISIONING.md` and `test/rules/firestore_rules_test.md`);
/// this helper is the client-side mirror used for UI gating and tests.
///
/// The two UIDs are **placeholders** until provisioning. Replace them
/// with the real Firebase Auth UIDs of the two partners — never commit
/// real service-account keys or passwords; UIDs themselves are not
/// secrets, but they must only ever be the two provisioned users.
library;

/// Placeholder UID for partner A — replace during provisioning.
/// (Intentionally obviously fake so it can never match a real user.)
const String kPartnerAUidPlaceholder = 'PARTNER_A_UID_PLACEHOLDER';

/// Placeholder UID for partner B — replace during provisioning.
const String kPartnerBUidPlaceholder = 'PARTNER_B_UID_PLACEHOLDER';

/// The two placeholder UIDs, in partner order.
const List<String> kPlaceholderAllowedUids = [
  kPartnerAUidPlaceholder,
  kPartnerBUidPlaceholder,
];

/// True when [uid] is exactly one of [allowedUids].
///
/// * Comparison is exact and case-sensitive (Firebase UIDs are
///   case-sensitive).
/// * An empty or null [uid] is never allowed.
/// * An empty [allowedUids] list allows nobody.
bool isAllowedUid(String? uid, List<String> allowedUids) {
  if (uid == null || uid.isEmpty) return false;
  if (allowedUids.isEmpty) return false;
  return allowedUids.contains(uid);
}

/// True when [uid] is one of the two placeholder UIDs.
/// Convenience for tests and for pre-provisioning builds.
bool isPlaceholderAllowedUid(String? uid) =>
    isAllowedUid(uid, kPlaceholderAllowedUids);

/// True when [uid] is the partner of [myUid] — i.e. the *other* UID in
/// a two-person [allowedUids] list. Returns false for unknown UIDs and
/// for lists that do not contain exactly two UIDs.
bool isPartnerUid(String? uid, String? myUid, List<String> allowedUids) {
  if (allowedUids.length != 2) return false;
  if (uid == null || myUid == null) return false;
  if (uid == myUid) return false;
  return allowedUids.contains(uid) && allowedUids.contains(myUid);
}
