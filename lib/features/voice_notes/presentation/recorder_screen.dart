import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../media/data/media_service.dart';
import '../data/voice_note_service.dart';

/// Press-and-hold voice recorder. Hold the mic button to record (max 5 min),
/// slide / tap Cancel to discard, release to stop, then Send or re-record.
class RecorderScreen extends StatefulWidget {
  const RecorderScreen({
    super.key,
    required this.conversationId,
    required this.myUid,
    required this.onSent,
  });

  final String conversationId;
  final String myUid;
  final void Function(String url, int durationMs) onSent;

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  late final VoiceNoteService _service;
  final MediaService _mediaService = MediaService();
  File? _recordedFile;
  Duration _elapsed = Duration.zero;
  Duration _recordedDuration = Duration.zero;
  StreamSubscription<Duration>? _elapsedSub;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = VoiceNoteService();
    _elapsedSub = _service.elapsedStream.listen((Duration d) {
      if (mounted) setState(() => _elapsed = d);
    });
  }

  @override
  void dispose() {
    _elapsedSub?.cancel();
    _service.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final bool ok = await _service.startRecording();
    if (!ok && mounted) {
      setState(
        () => _error = 'Microphone permission is needed to record.',
      );
    }
  }

  Future<void> _stop() async {
    final File? file = await _service.stopRecording();
    if (mounted) {
      setState(() {
        _recordedFile = file;
        _recordedDuration = _elapsed;
      });
    }
  }

  Future<void> _cancel() async {
    await _service.cancelRecording();
    if (mounted) {
      setState(() {
        _recordedFile = null;
        _elapsed = Duration.zero;
      });
    }
  }

  Future<void> _send() async {
    final File? file = _recordedFile;
    if (file == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final String url = await _mediaService.uploadFileWithRetry(
        coupleId: widget.conversationId,
        kind: 'voice',
        file: file,
      );
      if (!mounted) return;
      widget.onSent(url, _recordedDuration.inMilliseconds);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _format(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool recording = _service.isRecording;
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.midnight,
        title: const Text(
          'Voice note',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              recording ? 'Recording...' : 'Hold to record',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              _format(recording ? _elapsed : _recordedDuration),
              style: const TextStyle(
                color: AppColors.pink,
                fontSize: 40,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Max 5 minutes',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onLongPressStart: (_) => _start(),
              onLongPressEnd: (_) => _stop(),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: recording
                      ? const LinearGradient(
                          colors: <Color>[AppColors.error, AppColors.pink],
                        )
                      : AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  recording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            if (_recordedFile != null && !recording) ...<Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextButton(
                    onPressed: _cancel,
                    child: const Text(
                      'Discard',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GradientButton(
                    label: 'Send voice note',
                    isLoading: _uploading,
                    onPressed: _send,
                  ),
                ],
              ),
            ],
            if (recording)
              TextButton(
                onPressed: _cancel,
                child: const Text(
                  'Cancel recording',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
