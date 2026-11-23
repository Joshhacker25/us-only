/// Sealed-envelope countdown screen for a surprise.
///
/// Shows only the public title and a live countdown. The content is
/// never shown here. Timezone handling: `unlockAt` is stored in UTC;
/// it is converted with `.toLocal()` for display and for the countdown
/// math, so the countdown is correct no matter where either partner is.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/surprise_service.dart';
import 'surprise_provider.dart';
import 'surprise_reveal_screen.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class SurpriseCountdownScreen extends StatefulWidget {
  const SurpriseCountdownScreen({
    super.key,
    required this.coupleId,
    required this.surprise,
  });

  final String coupleId;
  final Surprise surprise;

  @override
  State<SurpriseCountdownScreen> createState() =>
      _SurpriseCountdownScreenState();
}

class _SurpriseCountdownScreenState extends State<SurpriseCountdownScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final unlockAt = widget.surprise.unlockAt;
    if (unlockAt == null) return;
    // Compare in local time on both sides of the subtraction so the
    // result is timezone-correct.
    final remaining = unlockAt.toLocal().difference(DateTime.now());
    if (mounted) {
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _countdownText() {
    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);
    if (days > 0) return '$days days, $hours hrs';
    if (hours > 0) return '$hours hrs, $minutes min';
    return '$minutes min, ${seconds.toString().padLeft(2, '0')} sec';
  }

  String _unlockText() {
    final unlockAt = widget.surprise.unlockAt;
    if (unlockAt == null) return '';
    final local = unlockAt.toLocal();
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Opens ${local.day} ${months[local.month - 1]} ${local.year} '
        'at $hour:$minute (your time)';
  }

  @override
  Widget build(BuildContext context) {
    final surprise = widget.surprise;
    final canOpen = _remaining == Duration.zero && surprise.isUnlockedLocally;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Sealed Surprise',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _purple, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _pink.withOpacity(0.25),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🎁', style: TextStyle(fontSize: 88)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              surprise.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A ${surprise.type.name} surprise — sealed tight.',
              style: const TextStyle(color: _lavender),
            ),
            const SizedBox(height: 24),
            if (!canOpen) ...[
              const Icon(Icons.lock, color: _pink, size: 28),
              const SizedBox(height: 12),
              Text(
                _countdownText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _unlockText(),
                style: const TextStyle(color: _lavender),
              ),
            ] else ...[
              const Icon(Icons.lock_open, color: _pink, size: 28),
              const SizedBox(height: 12),
              const Text(
                'It\'s time! 💕',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canOpen
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SurpriseRevealScreen(
                              coupleId: widget.coupleId,
                              surprise: surprise,
                            ),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Open it',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The unlock is checked on the server — changing your '
              'phone\'s clock cannot open it early.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _lavender, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
