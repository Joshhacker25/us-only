/// Active voice-call screen: avatar, timer, mute/speaker, hang up.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/webrtc_service.dart';
import 'call_provider.dart';

const _bg = Color(0xFF100B1F);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = d.inHours;
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

class VoiceCallScreen extends StatelessWidget {
  const VoiceCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CallProvider>();
    final connected =
        provider.connectionState == CallConnectionState.connected;
    final statusText = switch (provider.phase) {
      CallUiPhase.dialing => 'Calling…',
      CallUiPhase.active =>
        connected ? _formatDuration(provider.callDuration) : 'Connecting…',
      CallUiPhase.incoming => 'Incoming…',
      _ => 'Call ended',
    };

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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_purple, _pink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                statusText,
                style: const TextStyle(color: _lavender, fontSize: 16),
              ),
              if (provider.connectionState ==
                  CallConnectionState.disconnected)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Connection lost — trying to reconnect…',
                    style: TextStyle(color: Colors.amber, fontSize: 14),
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InCallButton(
                    icon: provider.isMuted ? Icons.mic_off : Icons.mic,
                    label: provider.isMuted ? 'Unmute' : 'Mute',
                    active: provider.isMuted,
                    onPressed: () => provider.toggleMute(),
                  ),
                  _InCallButton(
                    icon: Icons.volume_up,
                    label: 'Speaker',
                    active: provider.isSpeakerOn,
                    onPressed: () => provider.toggleSpeaker(),
                  ),
                  _InCallButton(
                    icon: Icons.call_end,
                    label: 'End',
                    background: Colors.red.shade600,
                    onPressed: () async {
                      await provider.endCall();
                      if (context.mounted) Navigator.of(context).pop();
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

class _InCallButton extends StatelessWidget {
  const _InCallButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.background,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? (active ? _pink : const Color(0xFF1B1230));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: _lavender, fontSize: 12)),
      ],
    );
  }
}
