/// Call state for the UI, driven by [CallSignalingService] + [WebRtcService].
///
/// Owns one active call at a time. The app shell (Part A) creates this
/// provider, feeds it the couple id + partner uid, and listens to
/// [CallSignalingService.watchIncomingCalls] to push the incoming-call
/// screen. This provider never dials anyone except the partner UID it
/// was constructed with.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/call_signaling_service.dart';
import '../data/webrtc_service.dart';

/// What the call UI is currently doing.
enum CallUiPhase {
  idle,
  dialing,
  incoming,
  active,
  ended,
}

class CallProvider extends ChangeNotifier {
  CallProvider({
    required this.coupleId,
    required this.partnerUid,
    required this.partnerNickname,
    CallSignalingService? signaling,
    WebRtcService? webrtc,
    FirebaseAuth? auth,
  })  : _signaling = signaling ?? CallSignalingService(),
        _webrtc = webrtc ?? WebRtcService(),
        _auth = auth ?? FirebaseAuth.instance {
    _webrtcSubscription =
        _webrtc.onConnectionState.listen(_onConnectionState);
    _incomingSubscription = _signaling
        .watchIncomingCalls(coupleId)
        .listen(_onIncomingSnapshot, onError: (_) {});
  }

  final String coupleId;
  final String partnerUid;
  final String partnerNickname;

  final CallSignalingService _signaling;
  final WebRtcService _webrtc;
  final FirebaseAuth _auth;

  StreamSubscription<CallConnectionState>? _webrtcSubscription;
  StreamSubscription<List<CallSession>>? _incomingSubscription;
  StreamSubscription<CallSession>? _activeCallSubscription;
  Timer? _ringingTimer;
  Timer? _callTimer;

  CallSession? _session;
  CallSession? get session => _session;

  CallUiPhase _phase = CallUiPhase.idle;
  CallUiPhase get phase => _phase;

  CallConnectionState _connectionState = CallConnectionState.idle;
  CallConnectionState get connectionState => _connectionState;

  bool get isMuted => _webrtc.isMuted;
  bool get isSpeakerOn => _webrtc.isSpeakerOn;
  bool get isVideoEnabled => _webrtc.isVideoEnabled;
  WebRtcService get webrtc => _webrtc;

  /// Elapsed time of the active call.
  Duration _callDuration = Duration.zero;
  Duration get callDuration => _callDuration;

  /// The most recent incoming ringing call, if any.
  CallSession? _incoming;
  CallSession? get incomingCall => _incoming;

  String get _myUid => _auth.currentUser?.uid ?? '';

  void _onConnectionState(CallConnectionState state) {
    _connectionState = state;
    if (state == CallConnectionState.connected && _callTimer == null) {
      _callTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          _callDuration += const Duration(seconds: 1);
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  void _onIncomingSnapshot(List<CallSession> ringing) {
    final next = ringing.isEmpty ? null : ringing.first;
    if (next?.id != _incoming?.id) {
      _incoming = next;
      if (next != null && _phase == CallUiPhase.idle) {
        _phase = CallUiPhase.incoming;
        _session = next;
      }
      notifyListeners();
    }
  }

  /// Start an outgoing call to the partner.
  Future<void> startCall(CallType type) async {
    if (_phase == CallUiPhase.dialing ||
        _phase == CallUiPhase.active) {
      return;
    }
    _phase = CallUiPhase.dialing;
    notifyListeners();
    try {
      await _webrtc.initialize(video: type == CallType.video);
      // Reserve the real session document first so the offer and ICE
      // candidates attach to the correct call id.
      final reserved = await _signaling.reserveCall(
        coupleId: coupleId,
        partnerUid: partnerUid,
        type: type,
      );
      final offer = await _webrtc.createOffer(
        coupleId: coupleId,
        callId: reserved.id,
      );
      await _signaling.updateOffer(
        coupleId: coupleId,
        callId: reserved.id,
        sdpOffer: offer,
      );
      final snap = await _signaling
          .watchCall(coupleId: coupleId, callId: reserved.id)
          .first;
      final created = snap;
      _session = created;
      _watchSession(created);
      // No answer within the ringing timeout -> mark missed.
      _ringingTimer?.cancel();
      _ringingTimer = Timer(
        CallSignalingService.ringingTimeout,
        () async {
          if (_phase == CallUiPhase.dialing && _session != null) {
            await _signaling.markMissedIfUnanswered(
              coupleId: coupleId,
              callId: _session!.id,
            );
            await endCall(reason: 'no answer');
          }
        },
      );
    } catch (_) {
      _phase = CallUiPhase.idle;
      await _webrtc.dispose();
      rethrow;
    }
    notifyListeners();
  }

  /// Accept the currently ringing incoming call.
  Future<void> acceptIncomingCall() async {
    final incoming = _incoming ?? _session;
    if (incoming == null) return;
    _ringingTimer?.cancel();
    _phase = CallUiPhase.active;
    notifyListeners();
    try {
      await _webrtc.initialize(video: incoming.isVideo);
      final answer = await _webrtc.createAnswer(
        coupleId: coupleId,
        callId: incoming.id,
        sdpOffer: incoming.offer ?? '',
      );
      await _signaling.acceptCall(
        coupleId: coupleId,
        callId: incoming.id,
        sdpAnswer: answer,
      );
      _session = incoming;
      _incoming = null;
      _watchSession(incoming);
    } catch (_) {
      await endCall(reason: 'accept failed');
      rethrow;
    }
    notifyListeners();
  }

  /// Decline the currently ringing incoming call.
  Future<void> rejectIncomingCall() async {
    final incoming = _incoming ?? _session;
    if (incoming == null) return;
    await _signaling.rejectCall(
      coupleId: coupleId,
      callId: incoming.id,
    );
    _incoming = null;
    _session = null;
    _phase = CallUiPhase.idle;
    notifyListeners();
  }

  /// Hang up / end the active or dialing call.
  Future<void> endCall({String reason = 'ended'}) async {
    _ringingTimer?.cancel();
    _callTimer?.cancel();
    _callTimer = null;
    final session = _session;
    if (session != null) {
      try {
        await _signaling.endCall(
          coupleId: coupleId,
          callId: session.id,
          reason: reason,
        );
      } catch (_) {
        // Signalling write failing must not block hanging up locally.
      }
    }
    await _webrtc.dispose();
    await _activeCallSubscription?.cancel();
    _activeCallSubscription = null;
    _session = null;
    _incoming = null;
    _callDuration = Duration.zero;
    _phase = CallUiPhase.ended;
    notifyListeners();
    _phase = CallUiPhase.idle;
    notifyListeners();
  }

  Future<void> toggleMute() async {
    await _webrtc.toggleMute();
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    await _webrtc.toggleSpeaker();
    notifyListeners();
  }

  Future<void> toggleVideo() async {
    await _webrtc.toggleVideo();
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await _webrtc.switchCamera();
  }

  void _watchSession(CallSession session) {
    unawaited(_activeCallSubscription?.cancel());
    _activeCallSubscription = _signaling
        .watchCall(coupleId: coupleId, callId: session.id)
        .listen((updated) async {
      _session = updated;
      switch (updated.state) {
        case CallState.accepted:
          _ringingTimer?.cancel();
          _phase = CallUiPhase.active;
          // Caller applies the callee's SDP answer.
          if (updated.callerUid == _myUid && updated.answer != null) {
            try {
              await _webrtc.applyAnswer(updated.answer!);
            } catch (_) {}
          }
        case CallState.rejected:
        case CallState.ended:
        case CallState.missed:
          if (_phase != CallUiPhase.idle) {
            await endCall(reason: updated.state.name);
          }
        case CallState.ringing:
          break;
      }
      notifyListeners();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _ringingTimer?.cancel();
    _callTimer?.cancel();
    _webrtcSubscription?.cancel();
    _incomingSubscription?.cancel();
    _activeCallSubscription?.cancel();
    super.dispose();
  }
}
