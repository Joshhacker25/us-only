/// Call signalling over Firestore for Only Us.
///
/// Exactly two people take part in a call: the signed-in user and their
/// partner. Every document in this feature is scoped to a couple document
/// (`couples/{coupleId}`) and Firestore security rules (owned by Part A)
/// must allow reads/writes only to the two UIDs listed on that couple
/// document. This service never trusts a caller/callee UID it did not get
/// from the authenticated session plus the couple document.
///
/// Signalling flow:
///   1. Caller creates a call document in
///      `couples/{coupleId}/call_sessions/{callId}` with state `ringing`,
///      `callerUid`, `calleeUid`, `isVideo`, and the SDP `offer`.
///   2. Callee listens to that document, answers by writing the SDP
///      `answer` and state `accepted`, or state `rejected`.
///   3. Both sides exchange ICE candidates in the `candidates`
///      sub-collection of the call document.
///   4. Either side ends the call by writing state `ended`.
///   5. If the callee never answers and the caller hangs up (or the
///      ringing document expires), the call is marked `missed`.
///
/// Reconnection note: this service is signalling only. If the network
/// drops mid-call, [WebRtcService] (see `webrtc_service.dart`) renegotiates
/// via ICE restart; the signalling document stays alive with state
/// `accepted` until either side writes `ended`, so a dropped peer can
/// re-join the same call document and re-exchange candidates instead of
/// starting a brand-new call. A call document left in `ringing` for more
/// than 60 seconds with no answer should be treated as `missed` by the
/// caller (see [markMissedIfUnanswered]) — the Cloud Function that sweeps
/// stale ringing calls is owned by Part A.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lifecycle states of a call session.
enum CallState {
  ringing,
  accepted,
  rejected,
  ended,
  missed,
}

/// Voice or video.
enum CallType { voice, video }

/// One call session, as stored in Firestore.
class CallSession {
  const CallSession({
    required this.id,
    required this.coupleId,
    required this.callerUid,
    required this.calleeUid,
    required this.type,
    required this.state,
    this.offer,
    this.answer,
    this.createdAt,
    this.endedAt,
    this.endReason,
  });

  factory CallSession.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CallSession(
      id: doc.id,
      coupleId: data['coupleId'] as String? ?? '',
      callerUid: data['callerUid'] as String? ?? '',
      calleeUid: data['calleeUid'] as String? ?? '',
      type: (data['isVideo'] as bool? ?? false)
          ? CallType.video
          : CallType.voice,
      state: _stateFromString(data['state'] as String?),
      offer: (data['offer'] as Map<String, dynamic>?)?['sdp'] as String?,
      answer:
          (data['answer'] as Map<String, dynamic>?)?['sdp'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      endReason: data['endReason'] as String?,
    );
  }

  static CallState _stateFromString(String? raw) {
    return CallState.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => CallState.ended,
    );
  }

  final String id;
  final String coupleId;
  final String callerUid;
  final String calleeUid;
  final CallType type;
  final CallState state;

  /// SDP offer string (caller -> callee).
  final String? offer;

  /// SDP answer string (callee -> caller).
  final String? answer;
  final DateTime? createdAt;
  final DateTime? endedAt;

  /// Human-readable reason, e.g. "caller hung up", "no answer".
  final String? endReason;

  bool get isVideo => type == CallType.video;

  /// True when this session involves [uid] as caller or callee.
  bool involves(String uid) => callerUid == uid || calleeUid == uid;

  /// The UID of the other person in this call, relative to [uid].
  String otherParty(String uid) => callerUid == uid ? calleeUid : callerUid;
}

/// Firestore signalling for 1-to-1 calls between the two partners.
class CallSignalingService {
  CallSignalingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const Duration ringingTimeout = Duration(seconds: 60);

  String get _myUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError(
        'CallSignalingService: no signed-in user. Calls require auth.',
      );
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _sessions(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('call_sessions');
  }

  DocumentReference<Map<String, dynamic>> _sessionDoc(
    String coupleId,
    String callId,
  ) {
    return _sessions(coupleId).doc(callId);
  }

  /// Starts a call: creates a `ringing` session holding the SDP offer.
  ///
  /// Returns the created session. Throws if [partnerUid] equals the
  /// caller's own UID — calls are only ever between the two partners.
  Future<CallSession> startCall({
    required String coupleId,
    required String partnerUid,
    required CallType type,
    required String sdpOffer,
  }) async {
    final session = await reserveCall(
      coupleId: coupleId,
      partnerUid: partnerUid,
      type: type,
    );
    await updateOffer(
      coupleId: coupleId,
      callId: session.id,
      sdpOffer: sdpOffer,
    );
    final snap = await _sessionDoc(coupleId, session.id).get();
    return CallSession.fromDoc(snap);
  }

  /// Creates the `ringing` session document *before* the SDP offer
  /// exists, so the offer (and ICE candidates) can be created against
  /// the real call id. Used by [CallProvider.startCall]; callers that
  /// already have an offer should use [startCall] instead.
  Future<CallSession> reserveCall({
    required String coupleId,
    required String partnerUid,
    required CallType type,
  }) async {
    final myUid = _myUid;
    if (partnerUid == myUid) {
      throw ArgumentError('Cannot call yourself.');
    }
    if (partnerUid.isEmpty || coupleId.isEmpty) {
      throw ArgumentError('coupleId and partnerUid are required.');
    }
    final doc = _sessions(coupleId).doc();
    await doc.set(<String, dynamic>{
      'coupleId': coupleId,
      'callerUid': myUid,
      'calleeUid': partnerUid,
      'isVideo': type == CallType.video,
      'state': CallState.ringing.name,
      'offer': null,
      'answer': null,
      'createdAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      'endReason': null,
    });
    final snap = await doc.get();
    return CallSession.fromDoc(snap);
  }

  /// Writes the SDP offer onto a session created by [reserveCall].
  Future<void> updateOffer({
    required String coupleId,
    required String callId,
    required String sdpOffer,
  }) async {
    final doc = _sessionDoc(coupleId, callId);
    final snap = await doc.get();
    _assertParticipant(CallSession.fromDoc(snap));
    await doc.update(<String, dynamic>{
      'offer': <String, dynamic>{'type': 'offer', 'sdp': sdpOffer},
    });
  }

  /// Callee: accept the call by writing the SDP answer.
  Future<void> acceptCall({
    required String coupleId,
    required String callId,
    required String sdpAnswer,
  }) async {
    final doc = _sessionDoc(coupleId, callId);
    final snap = await doc.get();
    final session = CallSession.fromDoc(snap);
    _assertParticipant(session);
    if (session.state != CallState.ringing) {
      throw StateError(
        'Cannot accept a call in state ${session.state.name}.',
      );
    }
    await doc.update(<String, dynamic>{
      'state': CallState.accepted.name,
      'answer': <String, dynamic>{'type': 'answer', 'sdp': sdpAnswer},
    });
  }

  /// Callee: decline the call.
  Future<void> rejectCall({
    required String coupleId,
    required String callId,
  }) async {
    final doc = _sessionDoc(coupleId, callId);
    final snap = await doc.get();
    _assertParticipant(CallSession.fromDoc(snap));
    await doc.update(<String, dynamic>{
      'state': CallState.rejected.name,
      'endedAt': FieldValue.serverTimestamp(),
      'endReason': 'declined',
    });
  }

  /// Either side: end an active or ringing call.
  Future<void> endCall({
    required String coupleId,
    required String callId,
    String reason = 'ended',
  }) async {
    final doc = _sessionDoc(coupleId, callId);
    final snap = await doc.get();
    if (!snap.exists) return;
    _assertParticipant(CallSession.fromDoc(snap));
    await doc.update(<String, dynamic>{
      'state': CallState.ended.name,
      'endedAt': FieldValue.serverTimestamp(),
      'endReason': reason,
    });
  }

  /// Caller: mark a call `missed` when nobody answered in time.
  /// Callers should invoke this after [ringingTimeout] of no answer;
  /// the callee's history then shows the call as missed.
  Future<void> markMissedIfUnanswered({
    required String coupleId,
    required String callId,
  }) async {
    final doc = _sessionDoc(coupleId, callId);
    final snap = await doc.get();
    if (!snap.exists) return;
    final session = CallSession.fromDoc(snap);
    if (session.state != CallState.ringing) return;
    await doc.update(<String, dynamic>{
      'state': CallState.missed.name,
      'endedAt': FieldValue.serverTimestamp(),
      'endReason': 'no answer',
    });
  }

  /// Live stream of one call session (offer/answer/state changes).
  Stream<CallSession> watchCall({
    required String coupleId,
    required String callId,
  }) {
    return _sessionDoc(coupleId, callId).snapshots().map(
      (snap) {
        if (!snap.exists) {
          throw StateError('Call session $callId no longer exists.');
        }
        return CallSession.fromDoc(snap);
      },
    );
  }

  /// Live stream of incoming ringing calls for the signed-in user.
  /// Used by the app shell to show the incoming-call screen.
  Stream<List<CallSession>> watchIncomingCalls(String coupleId) {
    final myUid = _myUid;
    return _sessions(coupleId)
        .where('calleeUid', isEqualTo: myUid)
        .where('state', isEqualTo: CallState.ringing.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(CallSession.fromDoc).toList(),
        );
  }

  /// Call history for this couple, newest first.
  Stream<List<CallSession>> watchCallHistory(
    String coupleId, {
    int limit = 50,
  }) {
    return _sessions(coupleId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(CallSession.fromDoc).toList());
  }

  /// Adds one ICE candidate to the call's `candidates` sub-collection.
  /// [fromUid] must be one of the two participants.
  Future<void> addIceCandidate({
    required String coupleId,
    required String callId,
    required String candidate,
    required String? sdpMid,
    required int? sdpMLineIndex,
  }) async {
    final doc = _sessionDoc(coupleId, callId);
    final snap = await doc.get();
    if (!snap.exists) return;
    _assertParticipant(CallSession.fromDoc(snap));
    await doc.collection('candidates').add(<String, dynamic>{
      'fromUid': _myUid,
      'candidate': candidate,
      'sdpMid': sdpMid,
      'sdpMLineIndex': sdpMLineIndex,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live stream of ICE candidates written by the *other* participant.
  Stream<List<Map<String, dynamic>>> watchRemoteIceCandidates({
    required String coupleId,
    required String callId,
  }) {
    final myUid = _myUid;
    return _sessionDoc(coupleId, callId)
        .collection('candidates')
        .where('fromUid', isNotEqualTo: myUid)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  void _assertParticipant(CallSession session) {
    if (!session.involves(_myUid)) {
      throw StateError(
        'Call session ${session.id} does not involve the signed-in user.',
      );
    }
  }
}
