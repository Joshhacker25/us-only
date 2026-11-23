/// WebRTC peer-connection wrapper for Only Us 1-to-1 calls.
///
/// Uses `flutter_webrtc`. Signalling (offer/answer/ICE) is done through
/// [CallSignalingService] — this class only owns the peer connection,
/// local/remote media, and in-call controls (mute, speaker, camera).
///
/// ICE servers:
///   * STUN: `stun:stun.relay.metered.ca:80` (Metered) + Google fallback.
///   * TURN: Metered, provisioned 2026-11-23 for app `only-us`
///     (domain only-us.metered.live, plan TURN TRIAL GLOBAL 500MB,
///     renews 2026-12-23). TURN is REQUIRED for reliable calls when
///     either partner is behind a symmetric NAT or on mobile data.
///     NOTE: these Metered credentials live in this private repo / APK
///     for this private two-person build. They are rotatable in one
///     click in the Metered dashboard (TURN Server page) — if they ever
///     leak, regenerate them there and update [iceServers] here.
///     The stronger long-term path is runtime delivery via a Cloud
///     Function (see docs/WEBRTC_TURN.md section 5).
library;

import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_signaling_service.dart';

/// Metered TURN credentials — provisioned 2026-11-23 (see file doc
/// comment for the rotation note). Username/credential are the same
/// across all TURN URLs below.
const String kTurnUsername = 'ba5d7d78a4960e7ff045ae61';
const String kTurnCredential = 'iRNlt/Yyd/gj0dx0';

/// Connection state reported to the UI.
enum CallConnectionState {
  idle,
  connecting,
  connected,
  disconnected,
  failed,
}

/// Thin wrapper around [RTCPeerConnection] for a single 1-to-1 call.
class WebRtcService {
  WebRtcService({CallSignalingService? signaling})
      : _signaling = signaling ?? CallSignalingService();

  final CallSignalingService _signaling;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  StreamSubscription<List<Map<String, dynamic>>>? _candidateSub;

  final _connectionStateController =
      StreamController<CallConnectionState>.broadcast();

  /// Emits connection-state changes for the UI to react to.
  Stream<CallConnectionState> get onConnectionState =>
      _connectionStateController.stream;

  CallConnectionState _state = CallConnectionState.idle;
  CallConnectionState get connectionState => _state;

  RTCVideoRenderer? get localRenderer => _localRenderer;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;
  bool get hasLocalStream => _localStream != null;

  bool _muted = false;
  bool get isMuted => _muted;

  bool _speakerOn = false;
  bool get isSpeakerOn => _speakerOn;

  bool _videoEnabled = true;
  bool get isVideoEnabled => _videoEnabled;

  /// ICE servers: Metered STUN + TURN (provisioned), Google STUN fallback.
  static Map<String, dynamic> get iceServers => <String, dynamic>{
        'iceServers': <Map<String, dynamic>>[
          <String, dynamic>{
            'urls': ['stun:stun.relay.metered.ca:80'],
          },
          <String, dynamic>{
            'urls': ['turn:global.relay.metered.ca:80'],
            'username': kTurnUsername,
            'credential': kTurnCredential,
          },
          <String, dynamic>{
            'urls': ['turn:global.relay.metered.ca:80?transport=tcp'],
            'username': kTurnUsername,
            'credential': kTurnCredential,
          },
          <String, dynamic>{
            'urls': ['turn:global.relay.metered.ca:443'],
            'username': kTurnUsername,
            'credential': kTurnCredential,
          },
          <String, dynamic>{
            'urls': ['turns:global.relay.metered.ca:443?transport=tcp'],
            'username': kTurnUsername,
            'credential': kTurnCredential,
          },
          <String, dynamic>{
            'urls': ['stun:stun.l.google.com:19302'],
          },
        ],
      };

  void _setState(CallConnectionState next) {
    _state = next;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(next);
    }
  }

  /// Prepares local media and renderers. Call before creating an offer
  /// or an answer. [video] false = voice-only call (audio track only).
  Future<void> initialize({required bool video}) async {
    await dispose();
    _videoEnabled = video;
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();

    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': video
          ? <String, dynamic>{
              'mandatory': <String, dynamic>{
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '24',
              },
              'facingMode': 'user',
              'optional': <dynamic>[],
            }
          : false,
    };
    _localStream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer!.srcObject = _localStream;
    _setState(CallConnectionState.connecting);
  }

  Future<RTCPeerConnection> _createPeerConnection({
    required String coupleId,
    required String callId,
  }) async {
    final pc = await createPeerConnection(iceServers);
    _pc = pc;

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer?.srcObject = event.streams.first;
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _setState(CallConnectionState.connected);
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _setState(CallConnectionState.disconnected);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _setState(CallConnectionState.failed);
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        case RTCPeerConnectionState.RTCPeerConnectionStateNew:
          _setState(CallConnectionState.connecting);
      }
    };

    // Forward our ICE candidates to the partner through Firestore.
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      unawaited(
        _signaling.addIceCandidate(
          coupleId: coupleId,
          callId: callId,
          candidate: candidate.candidate!,
          sdpMid: candidate.sdpMid,
          sdpMLineIndex: candidate.sdpMLineIndex,
        ),
      );
    };

    // Apply remote ICE candidates as they arrive.
    _candidateSub = _signaling
        .watchRemoteIceCandidates(coupleId: coupleId, callId: callId)
        .listen((candidates) async {
      for (final c in candidates) {
        final candidate = c['candidate'] as String?;
        if (candidate == null) continue;
        try {
          await pc.addCandidate(
            RTCIceCandidate(
              candidate,
              c['sdpMid'] as String?,
              c['sdpMLineIndex'] as int?,
            ),
          );
        } catch (_) {
          // A stale/duplicate candidate is not fatal; keep going.
        }
      }
    });
    return pc;
  }

  /// Caller: create the SDP offer to hand to [CallSignalingService.startCall].
  Future<String> createOffer({
    required String coupleId,
    required String callId,
  }) async {
    final pc = await _createPeerConnection(
      coupleId: coupleId,
      callId: callId,
    );
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    return offer.sdp ?? '';
  }

  /// Callee: apply the caller's offer and create the SDP answer.
  Future<String> createAnswer({
    required String coupleId,
    required String callId,
    required String sdpOffer,
  }) async {
    final pc = await _createPeerConnection(
      coupleId: coupleId,
      callId: callId,
    );
    await pc.setRemoteDescription(
      RTCSessionDescription(sdpOffer, 'offer'),
    );
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    return answer.sdp ?? '';
  }

  /// Caller: apply the callee's SDP answer after it arrives via signalling.
  Future<void> applyAnswer(String sdpAnswer) async {
    final pc = _pc;
    if (pc == null) {
      throw StateError('No peer connection — call initialize() first.');
    }
    await pc.setRemoteDescription(
      RTCSessionDescription(sdpAnswer, 'answer'),
    );
  }

  /// Mute / unmute the local microphone. Returns the new muted state.
  Future<bool> toggleMute() async {
    _muted = !_muted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_muted);
    return _muted;
  }

  /// Toggle the loudspeaker. Returns the new speaker state.
  Future<bool> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    try {
      await Helper.setSpeakerphoneOn(_speakerOn);
    } catch (_) {
      // Not all platforms support the helper; keep the flag anyway.
    }
    return _speakerOn;
  }

  /// Switch between front and back camera. Voice calls ignore this.
  Future<void> switchCamera() async {
    final videoTracks = _localStream?.getVideoTracks() ?? const [];
    if (videoTracks.isEmpty) return;
    final videoTrack = videoTracks.first;
    try {
      await Helper.switchCamera(videoTrack);
    } catch (_) {
      // Camera switch unsupported on this device; ignore.
    }
  }

  /// Enable / disable the local camera (video stays connected).
  Future<bool> toggleVideo() async {
    _videoEnabled = !_videoEnabled;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = _videoEnabled);
    return _videoEnabled;
  }

  /// End the call and release all media and the peer connection.
  ///
  /// Reconnection note: if the network drops, the peer connection reports
  /// `disconnected`; the UI should wait a few seconds before calling
  /// [dispose], because flutter_webrtc ICE will often recover on its own
  /// and the call can continue on the same signalling document. Only when
  /// the state becomes `failed` (or the user hangs up) is the call over.
  Future<void> dispose() async {
    await _candidateSub?.cancel();
    _candidateSub = null;
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
    try {
      await _localRenderer?.dispose();
    } catch (_) {}
    try {
      await _remoteRenderer?.dispose();
    } catch (_) {}
    _localRenderer = null;
    _remoteRenderer = null;
    _muted = false;
    _speakerOn = false;
    _setState(CallConnectionState.idle);
  }

  /// Closes the broadcast stream. Call once when the service is discarded.
  Future<void> disposeAll() async {
    await dispose();
    await _connectionStateController.close();
  }
}
