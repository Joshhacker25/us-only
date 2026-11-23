/// Nearby screen: discover + pair with the partner's phone and chat
/// offline over a direct device-to-device link. Includes the honest
/// limits disclosure — Bluetooth-only HD video and long-distance offline
/// calls are NOT supported; nearby calls need a shared Wi-Fi network.
library;

import 'package:flutter/material.dart';

import '../data/nearby_models.dart';
import '../data/nearby_service.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({
    super.key,
    required this.coupleId,
    required this.partnerNickname,
    required this.myUid,
    this.cipher,
  });

  final String coupleId;
  final String partnerNickname;
  final String myUid;

  /// Supplied by Part A wiring (shared EncryptionService). Without it,
  /// messages cannot be sent — see [NearbyService].
  final NearbyPayloadCipher? cipher;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  late final NearbyService _service;
  final _controller = TextEditingController();
  final List<NearbyMessage> _messages = <NearbyMessage>[];
  List<NearbyPeer> _peers = <NearbyPeer>[];
  NearbyConnectionState _state = NearbyConnectionState.idle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = NearbyService(
      coupleId: widget.coupleId,
      cipher: widget.cipher,
    );
    _service.onConnectionState.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _service.onPeers.listen((peers) {
      if (mounted) setState(() => _peers = peers);
    });
    _service.onMessage.listen((message) {
      if (mounted) setState(() => _messages.add(message));
    });
  }

  @override
  void dispose() {
    _service.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      await _service.startAdvertising();
      await _service.startDiscovery();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    try {
      final message = await _service.sendMessage(text);
      setState(() => _messages.add(message));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _state == NearbyConnectionState.connected;
    final queued = _service.pendingQueue.length;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Nearby',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          const NearbyLimitsDisclosure(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  connected ? Icons.bluetooth_connected : Icons.bluetooth,
                  color: connected ? Colors.green : _lavender,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusText(),
                    style: const TextStyle(color: _lavender),
                  ),
                ),
                if (!connected)
                  ElevatedButton(
                    onPressed: _start,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                    ),
                    child: const Text('Find partner'),
                  )
                else
                  TextButton(
                    onPressed: () => _service.stop(),
                    child: const Text(
                      'Stop',
                      style: TextStyle(color: _pink),
                    ),
                  ),
              ],
            ),
          ),
          if (queued > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$queued message${queued == 1 ? '' : 's'} queued '
                      'offline — will send when your partner is near.',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          if (_peers.isNotEmpty && !connected)
            ..._peers.map(
              (peer) => ListTile(
                leading: const CircleAvatar(
                  backgroundColor: _purple,
                  child: Icon(Icons.phone_android, color: Colors.white),
                ),
                title: const Text(
                  'Partner found nearby',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Verified by pairing token',
                  style: TextStyle(color: _lavender),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _service.connectToPeer(peer),
                  style: ElevatedButton.styleFrom(backgroundColor: _pink),
                  child: const Text('Connect'),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No nearby messages yet.\nGet close to your partner and say hi — no internet needed. 💕',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _lavender),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final mine = message.senderUid == widget.myUid;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: mine ? _purple : _card,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message.text,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: connected
                          ? 'Message nearby…'
                          : 'Message (will queue offline)…',
                      hintStyle: const TextStyle(color: _lavender),
                      filled: true,
                      fillColor: _card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _pink,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _send,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    return switch (_state) {
      NearbyConnectionState.idle => 'Nearby is off.',
      NearbyConnectionState.discovering ||
      NearbyConnectionState.advertising =>
        'Looking for ${widget.partnerNickname} nearby…',
      NearbyConnectionState.connecting => 'Connecting…',
      NearbyConnectionState.connected =>
        'Connected to ${widget.partnerNickname} — offline chat on.',
      NearbyConnectionState.disconnected => 'Disconnected.',
    };
  }
}

/// Honest limits disclosure. Shown at the top of the Nearby screen so
/// nobody expects what the link cannot do.
class NearbyLimitsDisclosure extends StatelessWidget {
  const NearbyLimitsDisclosure({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purple.withOpacity(0.5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: _pink, size: 20),
              SizedBox(width: 8),
              Text(
                'What Nearby can — and can’t — do',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Nearby chat works offline when your phones are close together.\n'
            '• Bluetooth-only HD video is NOT supported.\n'
            '• Long-distance offline calls are NOT supported.\n'
            '• Nearby calls need both phones on the same shared Wi-Fi network.',
            style: TextStyle(color: _lavender, height: 1.5),
          ),
        ],
      ),
    );
  }
}
