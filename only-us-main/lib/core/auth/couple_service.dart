/// Couple / conversation identity — Part A.
///
/// One couple, one conversation. The couple id is deterministic from
/// the two UIDs (sorted, joined) so both phones compute the same id
/// without a lookup. The couple document holds the pairing token used
/// by Nearby (server-issued, only readable by the two UIDs).
library;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/models/user_profile.dart';

class CoupleService {
  CoupleService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static String coupleIdFor(String uidA, String uidB) {
    final sorted = <String>[uidA, uidB]..sort();
    return 'couple_${sorted[0]}_${sorted[1]}';
  }

  String? get myUid => _auth.currentUser?.uid;

  Future<String?> partnerUid(List<String> allowedUids) async {
    final mine = myUid;
    if (mine == null) return null;
    for (final uid in allowedUids) {
      if (uid != mine) return uid;
    }
    return null;
  }

  String conversationIdFor(String coupleId) => 'conv_$coupleId';

  Future<UserProfile?> fetchPartner(
      String partnerUid) async {
    final doc = await _firestore.collection('users').doc(partnerUid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  Stream<UserProfile?> watchPartner(String partnerUid) =>
      _firestore.collection('users').doc(partnerUid).snapshots().map(
            (doc) => doc.exists ? UserProfile.fromFirestore(doc) : null,
          );

  /// Ensures the couple document exists with a pairing token.
  /// Returns the pairing token, or null when not signed in.
  Future<String?> ensureCoupleDocument(
      String coupleId, List<String> memberUids) async {
    final ref = _firestore.collection('couples').doc(coupleId);
    final snap = await ref.get();
    if (snap.exists) {
      return (snap.data()?['pairingToken'] as String?);
    }
    final token = _randomToken();
    await ref.set(<String, dynamic>{
      'memberUids': memberUids,
      'pairingToken': token,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return token;
  }

  Future<void> updateMyProfile(UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.uid)
        .set(profile.toFirestore(), SetOptions(merge: true));
  }

  String _randomToken() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List<String>.generate(
        32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
