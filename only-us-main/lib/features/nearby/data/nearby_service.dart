/// Offline nearby messaging over `flutter_nearby_connections` v1.
///
/// Plugin API (v1.1.2): `NearbyService.init(serviceType, strategy,
/// deviceName, callback)`, `startAdvertisingPeer()`,
/// `startBrowsingForPeers()`, `invitePeer(deviceID, deviceName)`,
/// `sendMessage(deviceID, message)`, `stateChangedSubscription` /
/// `dataReceivedSubscription`. There is no `Nearby` / `Status` / `Payload`
/// API in this version — earlier code targeting that API did not compile.
///
/// AUTHENTICATED PAIRING — only the partner, never strangers:
///   * The couple document (`couples/{coupleId}`) holds a server-issued
///     `pairingToken`: a random string only the two partner UIDs can read.
///   * Each phone advertises deviceName `onlyus:<pairingToken>`.
///   * On discovery, the token in the peer's device name is compared
///     with the token read from the couple document. A mismatch means
///     the device is NOT the partner: it is never invited.
///   * Pairing is re-verified on every new connection, not just the first.
///
/// ENCRYPTED TRANSPORT: message payloads are encrypted before they
/// leave the device, using the couple's shared [NearbyPayloadCipher].
/// If no cipher is supplied, [sendMessage] refuses to send content
/// (it throws) rather than leaking plaintext over the air.
///
/// QUEUE / RECONNECT / SYNC / DEDUP: messages sent while disconnected
/// are queued in memory; on reconnect they are sent oldest first;
/// every message carries a sender-generated `clientId`; receivers
/// ignore any `clientId` they have already seen.
///
/// LIMITS: nearby messaging works offline over Bluetooth / local Wi-Fi.
/// HD video and long-distance offline calls are NOT supported over
/// this link. Nearby calls need both phones on the SAME Wi-Fi network.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart'
    as nearby;

import 'nearby_models.dart';

abstract class NearbyPayloadCipher {
  String encrypt(String plaintext);
  String? decrypt(String ciphertext);
}

class _Envelope {
  const _Envelope({required this.kind, required this.payload});

  factory _Envelope.fromJson(Map<String, dynamic> json) => _Envelope(
        kind: json['kind'] as String? ?? '',
        payload: json['payload'] as Map<String, dynamic>? ?? const {},
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'payload': payload,
      };

  final String kind;
  final Map<String, dynamic> payload;
}

class NearbyService {
  NearbyService({
    required this.coupleId,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NearbyPayloadCipher? cipher,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _cipher = cipher,
        _nearby = nearby.NearbyService();

  final String coupleId;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NearbyPayloadCipher? _cipher;
  final nearby.NearbyService _nearby;

  static const nearby.Strategy _strategy = nearby.Strategy.P2P_CLUSTER;
  static const String _servicePrefix = 'onlyus';

  final _stateController =
      StreamController<NearbyConnectionState>.broadcast();
  final _messageController = StreamController<NearbyMessage>.broadcast();
  final _peerController = StreamController<List<NearbyPeer>>.broadcast();

  Stream<NearbyConnectionState> get onConnectionState =>
      _stateController.stream;
  Stream<NearbyMessage> get onMessage => _messageController.stream;
  Stream<List<NearbyPeer>> get onPeers => _peerController.stream;

  NearbyConnectionState _state = NearbyConnectionState.idle;
  NearbyConnectionState get connectionState => _state;

  String? _pairingToken;
  String? _connectedDeviceId;
  String? get connectedEndpointId => _connectedDeviceId;
  bool get isConnected => _state == NearbyConnectionState.connected;

  final Map<String, NearbyPeer> _discovered = {};
  final List<NearbyMessage> _queue = [];
  final Set<String> _seenClientIds = <String>{};
  final List<NearbyMessage> _received = [];
  bool _initialised = false;
  StreamSubscription? _stateSub;
  StreamSubscription? _dataSub;

  List<NearbyMessage> get receivedMessages =>
      List<NearbyMessage>.unmodifiable(_received);
  List<NearbyMessage> get pendingQueue =>
      List<NearbyMessage>.unmodifiable(_queue);

  String get _myUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('NearbyService: no signed-in user.');
    }
    return uid;
  }

  void _setState(NearbyConnectionState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  String _newClientId() {
    final random = Random.secure();
    final suffix = List<int>.generate(12, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${_myUid}_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }

  Future<String> _loadPairingToken() async {
    if (_pairingToken != null) return _pairingToken!;
    final doc =
        await _firestore.collection('couples').doc(coupleId).get();
    final token = (doc.data() ?? const {})['pairingToken'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError(
        'Couple document has no pairingToken. Pairing cannot be '
        'verified — nearby is disabled until provisioning.',
      );
    }
    _pairingToken = token;
    return token;
  }

  Future<void> _initPlugin() async {
    if (_initialised) return;
    final token = await _loadPairingToken();
    await _nearby.init(
      serviceType: _servicePrefix,
      strategy: _strategy,
      deviceName: '$_servicePrefix:$token',
      callback: (bool isRunning) {},
    );
    _stateSub = _nearby.stateChangedSubscription(
      callback: _onDevicesChanged,
    );
    _dataSub = _nearby.dataReceivedSubscription(
      callback: _onDataReceived,
    );
    _initialised = true;
  }

  void _onDevicesChanged(List<nearby.Device> devices) {
    for (final device in devices) {
      final presented = _tokenFromName(device.deviceName);
      if (presented.isEmpty || presented != _pairingToken) continue;
      if (device.state == nearby.SessionState.connected) {
        _connectedDeviceId = device.deviceId;
        _discovered[device.deviceId] = NearbyPeer(
          endpointId: device.deviceId,
          endpointName: device.deviceName,
          presentedToken: presented,
        );
        if (_state != NearbyConnectionState.connected) {
          _setState(NearbyConnectionState.connected);
          _sendSync();
          _flushQueue();
        }
      } else if (device.state == nearby.SessionState.notConnected) {
        if (device.deviceId == _connectedDeviceId) {
          _connectedDeviceId = null;
          _setState(NearbyConnectionState.disconnected);
        }
        _discovered.remove(device.deviceId);
      } else {
        _discovered[device.deviceId] = NearbyPeer(
          endpointId: device.deviceId,
          endpointName: device.deviceName,
          presentedToken: presented,
        );
      }
    }
    if (!_peerController.isClosed) {
      _peerController.add(_discovered.values.toList());
    }
  }

  String _tokenFromName(String name) {
    if (!name.startsWith('$_servicePrefix:')) return '';
    return name.substring(_servicePrefix.length + 1);
  }

  Future<void> startAdvertising() async {
    await _initPlugin();
    _setState(NearbyConnectionState.advertising);
    await _nearby.startAdvertisingPeer();
  }

  Future<void> startDiscovery() async {
    await _initPlugin();
    _setState(NearbyConnectionState.discovering);
    await _nearby.startBrowsingForPeers();
  }

  Future<void> connectToPeer(NearbyPeer peer) async {
    if (peer.presentedToken != _pairingToken) {
      throw StateError('Refusing to connect: pairing token mismatch.');
    }
    _setState(NearbyConnectionState.connecting);
    await _nearby.invitePeer(
      deviceID: peer.endpointId,
      deviceName: peer.endpointName,
    );
  }

  Future<NearbyMessage> sendMessage(String text) async {
    final cipher = _cipher;
    if (cipher == null) {
      throw StateError(
        'No NearbyPayloadCipher configured: refusing to send message '
        'content unencrypted. Wire the shared EncryptionService in.',
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError('Cannot send an empty message.');
    final message = NearbyMessage(
      clientId: _newClientId(),
      senderUid: _myUid,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    _seenClientIds.add(message.clientId);
    if (isConnected) {
      await _sendMessageNow(message, cipher);
    } else {
      _queue.add(message);
    }
    return message;
  }

  Future<void> _sendMessageNow(
    NearbyMessage message,
    NearbyPayloadCipher cipher,
  ) async {
    final encrypted = cipher.encrypt(message.text);
    await _sendEnvelope(
      _Envelope(kind: 'msg', payload: <String, dynamic>{
        'clientId': message.clientId,
        'senderUid': message.senderUid,
        'createdAt': message.createdAt.toIso8601String(),
        'ciphertext': encrypted,
      }),
    );
    _queue.removeWhere((m) => m.clientId == message.clientId);
  }

  Future<void> _flushQueue() async {
    final cipher = _cipher;
    if (cipher == null || !isConnected) return;
    for (final message in List<NearbyMessage>.from(_queue)) {
      try {
        await _sendMessageNow(message, cipher);
      } catch (_) {
        break;
      }
    }
  }

  Future<void> _sendSync() async {
    await _sendEnvelope(
      _Envelope(kind: 'sync', payload: <String, dynamic>{
        'knownClientIds': _seenClientIds.toList(),
      }),
    );
  }

  Future<void> _sendEnvelope(_Envelope envelope) async {
    final deviceId = _connectedDeviceId;
    if (deviceId == null) return;
    await _nearby.sendMessage(deviceId, jsonEncode(envelope.toJson()));
  }

  void _onDataReceived(dynamic data) {
    String raw;
    if (data is String) {
      raw = data;
    } else if (data is Map) {
      raw = jsonEncode(data);
    } else {
      return;
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final envelope = _Envelope.fromJson(json);
    switch (envelope.kind) {
      case 'msg':
        _handleIncomingMessage(envelope.payload);
      case 'ack':
        final clientId = envelope.payload['clientId'] as String? ?? '';
        _queue.removeWhere((m) => m.clientId == clientId);
      case 'sync':
        _handleSync(envelope.payload);
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> payload) {
    final clientId = payload['clientId'] as String? ?? '';
    if (clientId.isEmpty || _seenClientIds.contains(clientId)) return;
    final ciphertext = payload['ciphertext'] as String?;
    final cipher = _cipher;
    if (ciphertext == null || cipher == null) return;
    final plaintext = cipher.decrypt(ciphertext);
    if (plaintext == null) return;
    _seenClientIds.add(clientId);
    final message = NearbyMessage(
      clientId: clientId,
      senderUid: payload['senderUid'] as String? ?? '',
      text: plaintext,
      createdAt:
          DateTime.tryParse(payload['createdAt'] as String? ?? '') ??
              DateTime.now(),
      delivered: true,
      acked: true,
    );
    _received.add(message);
    if (!_messageController.isClosed) _messageController.add(message);
    unawaited(
      _sendEnvelope(
        _Envelope(kind: 'ack', payload: <String, dynamic>{
          'clientId': clientId,
        }),
      ),
    );
  }

  void _handleSync(Map<String, dynamic> payload) {
    final known = (payload['knownClientIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toSet();
    final cipher = _cipher;
    if (cipher == null || !isConnected) return;
    for (final message in List<NearbyMessage>.from(_queue)) {
      if (!known.contains(message.clientId)) {
        unawaited(_sendMessageNow(message, cipher));
      }
    }
  }

  Future<void> stop() async {
    try {
      await _nearby.stopAdvertisingPeer();
    } catch (_) {}
    try {
      await _nearby.stopBrowsingForPeers();
    } catch (_) {}
    final deviceId = _connectedDeviceId;
    if (deviceId != null) {
      try {
        await _nearby.disconnectPeer(deviceID: deviceId);
      } catch (_) {}
    }
    _connectedDeviceId = null;
    _setState(NearbyConnectionState.idle);
  }

  Future<void> dispose() async {
    await stop();
    await _stateSub?.cancel();
    await _dataSub?.cancel();
    await _stateController.close();
    await _messageController.close();
    await _peerController.close();
  }
}
