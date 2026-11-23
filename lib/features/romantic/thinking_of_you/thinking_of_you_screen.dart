/// Thinking-of-you screen: tap the heart for a gentle pulse,
/// long-press for a stronger animation. Haptics on every send.
/// Respects the 1-heart-per-10-seconds throttle and the partner's
/// opt-out (see [ThinkingOfYouService]).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'thinking_of_you_service.dart';

const _bg = Color(0xFF100B1F);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class ThinkingOfYouScreen extends StatefulWidget {
  const ThinkingOfYouScreen({
    super.key,
    required this.coupleId,
    required this.partnerUid,
    required this.partnerNickname,
  });

  final String coupleId;
  final String partnerUid;
  final String partnerNickname;

  @override
  State<ThinkingOfYouScreen> createState() => _ThinkingOfYouScreenState();
}

class _ThinkingOfYouScreenState extends State<ThinkingOfYouScreen>
    with SingleTickerProviderStateMixin {
  late final ThinkingOfYouService _service;
  late final AnimationController _pulseController;
  ThinkingOfYouSettings? _partnerSettings;
  bool _loadingSettings = true;
  String? _hint;

  @override
  void initState() {
    super.initState();
    _service = ThinkingOfYouService();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings =
          await _service.loadPartnerSettings(widget.partnerUid);
      if (mounted) setState(() => _partnerSettings = settings);
    } catch (_) {
      // Fail-open: hearts still send; notification sender re-checks.
    } finally {
      if (mounted) setState(() => _loadingSettings = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _sendHeart({required bool strong}) async {
    final result = await _service.sendHeart(
      coupleId: widget.coupleId,
      partnerUid: widget.partnerUid,
      partnerSettings: _partnerSettings,
    );
    switch (result) {
      case HeartSendResult.sent:
        // Gentle pulse on tap; bigger, longer pulse on long-press.
        _pulseController.duration = Duration(
          milliseconds: strong ? 1100 : 700,
        );
        _pulseController.forward(from: 0);
        if (strong) {
          await HapticFeedback.heavyImpact();
        } else {
          await HapticFeedback.lightImpact();
        }
        if (mounted) {
          setState(() => _hint = null);
        }
      case HeartSendResult.throttled:
        await HapticFeedback.selectionClick();
        if (mounted) {
          setState(
            () => _hint = 'Slow down, love — one heart every 10 seconds. 💕',
          );
        }
      case HeartSendResult.optedOut:
        if (mounted) {
          setState(
            () => _hint =
                '${widget.partnerNickname} turned hearts off for now.',
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final optedOut = _partnerSettings?.heartsOptedOut == true;
    final quiet = _partnerSettings?.isQuietAt(DateTime.now()) == true;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Thinking of You',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: optedOut || _loadingSettings
                  ? null
                  : () => _sendHeart(strong: false),
              onLongPress: optedOut || _loadingSettings
                  ? null
                  : () => _sendHeart(strong: true),
              child: ScaleTransition(
                scale: Tween<double>(begin: 1, end: 1.35).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.elasticOut,
                  ),
                ),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_purple, _pink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _pink.withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('❤️', style: TextStyle(fontSize: 84)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              optedOut
                  ? '${widget.partnerNickname} turned hearts off for now.'
                  : 'Tap to send a gentle heart.\nLong-press for a big one.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _lavender, fontSize: 16),
            ),
            if (quiet && !optedOut) ...[
              const SizedBox(height: 12),
              const Text(
                '🌙 It\'s quiet hours for your love — the heart will arrive silently.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _lavender, fontSize: 14),
              ),
            ],
            if (_hint != null) ...[
              const SizedBox(height: 16),
              Text(
                _hint!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _pink, fontSize: 14),
              ),
            ],
            const Spacer(),
            const Text(
              'Max 1 heart every 10 seconds, 20 per hour — so every heart means something.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _lavender, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
