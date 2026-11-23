import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../shared/models/message.dart';
import '../../../shared/theme/app_colors.dart';
import '../data/voice_note_service.dart';

String formatVoiceDuration(int? durationMs) {
  if (durationMs == null) return '0:00';
  final Duration d = Duration(milliseconds: durationMs);
  final int minutes = d.inMinutes;
  final int seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Voice message bubble: play / pause, a waveform-ish progress bar
/// (segmented bars filled by playback progress) and the duration.
class VoiceNoteBubble extends StatefulWidget {
  const VoiceNoteBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  final Message message;
  final bool isMine;

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  late final VoiceNoteService _service;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _service = VoiceNoteService();
    _duration = Duration(milliseconds: widget.message.durationMs ?? 0);
    _service.positionStream.listen((Duration p) {
      if (mounted) setState(() => _position = p);
    });
    _service.durationStream.listen((Duration? d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
    _service.playerStateStream.listen((PlayerState state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        setState(() => _position = Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final String? url = widget.message.mediaUrl;
    if (url == null) return;
    if (_isPlaying) {
      await _service.pause();
    } else if (_position > Duration.zero) {
      await _service.resume();
    } else {
      await _service.playUrl(url);
    }
  }

  void _onSeek(double fraction) {
    if (_duration == Duration.zero) return;
    final Duration target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction).round(),
    );
    _service.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final double fraction = _duration.inMilliseconds <= 0
        ? 0
        : _position.inMilliseconds / _duration.inMilliseconds;
    const int bars = 24;
    final int filled = (fraction * bars).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          color: Colors.white,
          onPressed: _togglePlay,
        ),
        GestureDetector(
          onTapDown: (TapDownDetails details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final double width = box.size.width;
            if (width > 0) {
              // Seek relative to the whole bubble row is approximate; the
              // bar itself is the tap target in practice.
              _onSeek(details.localPosition.dx / width);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(bars, (int i) {
              final double height = 8 + (i % 5) * 4;
              return Container(
                width: 3,
                height: height.toDouble(),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: i < filled ? AppColors.pink : Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatVoiceDuration(_duration.inMilliseconds),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
