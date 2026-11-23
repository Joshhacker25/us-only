/// Romantic events (hugs, kisses, hearts, thinking-of-you) in Firestore.
///
/// Path: `couples/{coupleId}/romantic_events/{eventId}`.
/// Every event carries a server timestamp so ordering is consistent on
/// both phones. `clientEventId` is the dedup key: if a retry writes the
/// same event twice, the second write lands on the same document id and
/// cannot duplicate it. Events are tiny on purpose — a type, a sender,
/// and a timestamp — never message content.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Types of romantic event. Keep this list fixed — the UI animates
/// per type, and the widget reads the latest `heart` event.
enum RomanticEventType {
  hug,
  kiss,
  heart,
  thinkingOfYou,
}

/// One romantic event.
class RomanticEvent {
  const RomanticEvent({
    required this.id,
    required this.clientEventId,
    required this.senderUid,
    required this.type,
    this.createdAt,
  });

  factory RomanticEvent.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return RomanticEvent(
      id: doc.id,
      clientEventId: data['clientEventId'] as String? ?? doc.id,
      senderUid: data['senderUid'] as String? ?? '',
      type: RomanticEventType.values.firstWhere(
        (t) => t.name == (data['type'] as String?),
        orElse: () => RomanticEventType.heart,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String clientEventId;
  final String senderUid;
  final RomanticEventType type;
  final DateTime? createdAt;

  String get emoji => switch (type) {
        RomanticEventType.hug => '🤗',
        RomanticEventType.kiss => '💋',
        RomanticEventType.heart => '❤️',
        RomanticEventType.thinkingOfYou => '💭',
      };

  String get label => switch (type) {
        RomanticEventType.hug => 'Hug',
        RomanticEventType.kiss => 'Kiss',
        RomanticEventType.heart => 'Heart',
        RomanticEventType.thinkingOfYou => 'Thinking of you',
      };
}

class RomanticEventService {
  RomanticEventService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _myUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('RomanticEventService: no signed-in user.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _events(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('romantic_events');
  }

  String _newClientEventId() {
    return '${_myUid}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Sends one romantic event. Idempotent: calling it twice with the
  /// same [clientEventId] writes the same document, never a duplicate.
  /// Returns the created event.
  Future<RomanticEvent> sendEvent({
    required String coupleId,
    required RomanticEventType type,
    String? clientEventId,
  }) async {
    final id = clientEventId ?? _newClientEventId();
    final doc = _events(coupleId).doc(id);
    await doc.set(<String, dynamic>{
      'clientEventId': id,
      'senderUid': _myUid,
      'type': type.name,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final snap = await doc.get();
    return RomanticEvent.fromDoc(snap);
  }

  /// Recent romantic events, newest first.
  Stream<List<RomanticEvent>> watchRecentEvents(
    String coupleId, {
    int limit = 30,
  }) {
    return _events(coupleId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(RomanticEvent.fromDoc).toList());
  }

  /// The latest heart event (used by the home-screen widget).
  Future<RomanticEvent?> latestHeart(String coupleId) async {
    final snap = await _events(coupleId)
        .where('type', isEqualTo: RomanticEventType.heart.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return RomanticEvent.fromDoc(snap.docs.first);
  }
}
