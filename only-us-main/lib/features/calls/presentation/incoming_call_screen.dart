/// Incoming-call screen: full-screen ringing UI for an inbound call.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'call_provider.dart';
import 'video_call_screen.dart';
import 'voice_call_screen.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CallProvider>();
    final session = provider.incomingCall ?? provider.session;
    final isVideo = session?.isVideo ?? false;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_purple, _pink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _pink.withOpacity(0.45),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    provider.partnerNickname.isNotEmpty
                        ? provider.partnerNickname[0].toUpperCase()
                        : '💕',
                    style: const TextStyle(
                      fontSize: 52,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                provider.partnerNickname,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isVideo
                    ? 'Incoming video call…'
                    : 'Incoming voice call…',
                style: const TextStyle(color: _lavender, fontSize: 16),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallActionButton(
                    icon: Icons.call_end,
                    label: 'Decline',
                    background: Colors.red.shade600,
                    onPressed: () async {
                      await provider.rejectIncomingCall();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  _CallActionButton(
                    icon: isVideo ? Icons.videocam : Icons.call,
                    label: 'Accept',
                    background: Colors.green.shade600,
                    onPressed: () async {
                      await provider.acceptIncomingCall();
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => isVideo
                              ? const VideoCallScreen()
                              : const VoiceCallScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: _lavender)),
      ],
    );
  }
}
