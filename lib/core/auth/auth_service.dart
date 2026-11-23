/// Auth + two-person allowlist gate — Part A.
///
/// Firebase Auth (email/password) restores the session automatically.
/// After sign-in, the UID must be one of the two provisioned UIDs
/// (see lib/shared/utils/allowlist.dart and docs/PROVISIONING.md).
/// A third UID is signed out immediately and denied — the real
/// enforcement is in Firestore/Storage rules, this is the client gate.
library;

import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/utils/allowlist.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// True only when a user is signed in AND on the allowlist.
  /// When [allowedUids] is still the placeholders, nobody is allowed
  /// (placeholders never match a real UID) — provisioning must replace
  /// them first.
  bool isAuthorized(List<String> allowedUids) {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    if (allowedUids.contains(kPartnerAUidPlaceholder) ||
        allowedUids.contains(kPartnerBUidPlaceholder)) {
      // Not provisioned yet: fail closed.
      if (allowedUids.length != 2) return false;
    }
    return isAllowedUid(uid, allowedUids);
  }

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  /// Deny + sign out a non-allowlisted user. Returns true if allowed.
  Future<bool> enforceAllowlist(List<String> allowedUids) async {
    if (isAuthorized(allowedUids)) return true;
    await signOut();
    return false;
  }
}
