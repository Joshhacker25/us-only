/// Active video-call screen: remote video full-screen, local preview
/// picture-in-picture, mute / camera / speaker / switch-camera controls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../data/webrtc_service.dart';
import 'call_provider.dart';

const _bg = Color(0xFF100B1F);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = d.inHours;
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

class VideoCallScreen extends StatelessWidget {
  const VideoCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CallProvider>();
    final webrtc = provider.webrtc;
    final connected =
        provider.connectionState == CallConnectionState.connected;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video fills the screen; avatar placeholder until the
            // remote track arrives.
            Positioned.fill(
              child: webrtc.remoteRenderer != null
                  ? RTCVideoView(
                      webrtc.remoteRenderer!,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      color: _bg,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: const Color(0xFF7C3AED),
                              child: Text(
                                provider.partnerNickname.isNotEmpty
                                    ? provider.partnerNickname[0]
                                        .toUpperCase()
                                    : '💕',
                                style: const TextStyle(
                                  fontSize: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              provider.partnerNickname,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              connected
                                  ? _formatDuration(provider.callDuration)
                                  : 'Connecting video…',
                              style: const TextStyle(color: _lavender),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            // Call timer + connection banner on top.
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    provider.partnerNickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                  Text(
                    connected
                        ? _formatDuration(provider.callDuration)
                        : 'Connecting…',
                    style: const TextStyle(
                      color: _lavender,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                  if (provider.connectionState ==
                      CallConnectionState.disconnected)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Connection lost — trying to reconnect…',
                        style: TextStyle(color: Colors.amber),
                      ),
                    ),
                ],
              ),
            ),
            // Local preview, picture-in-picture.
            if (webrtc.localRenderer != null && provider.isVideoEnabled)
              Positioned(
                top: 72,
                right: 16,
                width: 112,
                height: 168,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(
                    webrtc.localRenderer!,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            // Controls along the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _VideoControlButton(
                    icon: provider.isMuted ? Icons.mic_off : Icons.mic,
                    label: provider.isMuted ? 'Unmute' : 'Mute',
                    active: provider.isMuted,
                    onPressed: () => provider.toggleMute(),
                  ),
                  _VideoControlButton(
                    icon: provider.isVideoEnabled
                        ? Icons.videocam
                        : Icons.videocam_off,
                    label: 'Camera',
                    active: !provider.isVideoEnabled,
                    onPressed: () => provider.toggleVideo(),
                  ),
                  _VideoControlButton(
                    icon: Icons.switch_camera,
                    label: 'Flip',
                    onPressed: () => provider.switchCamera(),
                  ),
                  _VideoControlButton(
                    icon: Icons.volume_up,
                    label: 'Speaker',
                    active: provider.isSpeakerOn,
                    onPressed: () => provider.toggleSpeaker(),
                  ),
                  _VideoControlButton(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoControlButton extends StatelessWidget {
  const _VideoControlButton({
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
    final bg = background ??
        (active ? _pink : Colors.black.withOpacity(0.55));
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
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            shadows: [Shadow(blurRadius: 6, color: Colors.black)],
          ),
        ),
      ],
    );
  }
}
