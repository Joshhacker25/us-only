/// Hugs & kisses screen: big Hug and Kiss buttons with a burst
/// animation, plus the recent romantic-events history.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'romantic_event_service.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class HugsKissesScreen extends StatefulWidget {
  const HugsKissesScreen({
    super.key,
    required this.coupleId,
    required this.partnerNickname,
  });

  final String coupleId;
  final String partnerNickname;

  @override
  State<HugsKissesScreen> createState() => _HugsKissesScreenState();
}

class _HugsKissesScreenState extends State<HugsKissesScreen>
    with SingleTickerProviderStateMixin {
  late final RomanticEventService _service;
  late final AnimationController _burstController;
  String _burstEmoji = '💕';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _service = RomanticEventService();
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  Future<void> _send(RomanticEventType type) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _burstEmoji = type == RomanticEventType.hug ? '🤗' : '💋';
    });
    _burstController.forward(from: 0);
    try {
      await _service.sendEvent(coupleId: widget.coupleId, type: type);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Hugs & Kisses',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          // Animated burst that plays on every send.
          SizedBox(
            height: 120,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.4, end: 1.4).animate(
                CurvedAnimation(
                  parent: _burstController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 1, end: 0.2).animate(
                  _burstController,
                ),
                child: Text(_burstEmoji, style: const TextStyle(fontSize: 96)),
              ),
            ),
          ),
          Text(
            'Send ${widget.partnerNickname} some love',
            style: const TextStyle(color: _lavender, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LoveButton(
                emoji: '🤗',
                label: 'Hug',
                onPressed: _sending
                    ? null
                    : () => _send(RomanticEventType.hug),
              ),
              _LoveButton(
                emoji: '💋',
                label: 'Kiss',
                onPressed: _sending
                    ? null
                    : () => _send(RomanticEventType.kiss),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Recent',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<RomanticEvent>>(
              stream: _service.watchRecentEvents(widget.coupleId),
              builder: (context, snapshot) {
                final events = snapshot.data ?? const <RomanticEvent>[];
                if (events.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nothing yet — be the first. 💕',
                      style: TextStyle(color: _lavender),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final mine = event.senderUid == myUid;
                    final time = event.createdAt?.toLocal();
                    final timeText = time == null
                        ? ''
                        : '${time.hour.toString().padLeft(2, '0')}:'
                            '${time.minute.toString().padLeft(2, '0')}';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Text(
                          event.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: Text(
                          mine
                              ? 'You sent a ${event.label.toLowerCase()}'
                              : '${widget.partnerNickname} sent a '
                                  '${event.label.toLowerCase()}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: Text(
                          timeText,
                          style: const TextStyle(color: _lavender),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveButton extends StatelessWidget {
  const _LoveButton({
    required this.emoji,
    required this.label,
    required this.onPressed,
  });

  final String emoji;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: _purple,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(emoji, style: const TextStyle(fontSize: 44)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
