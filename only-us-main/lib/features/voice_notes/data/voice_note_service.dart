import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Voice notes: press-and-hold record (max 5 minutes), cancel, mic
/// permission handling, and playback with play / pause / seek / duration.
class VoiceNoteService {
  VoiceNoteService({AudioRecorder? recorder, AudioPlayer? player})
      : _recorder = recorder ?? AudioRecorder(),
        _player = player ?? AudioPlayer();

  final AudioRecorder _recorder;
  final AudioPlayer _player;

  static const Duration maxDuration = Duration(minutes: 5);

  bool _isRecording = false;
  String? _currentPath;
  Timer? _maxTimer;
  final StreamController<Duration> _elapsedController =
      StreamController<Duration>.broadcast();

  bool get isRecording => _isRecording;
  String? get currentPath => _currentPath;

  /// Stream of elapsed recording time (for the UI timer).
  Stream<Duration> get elapsedStream => _elapsedController.stream;

  /// Playback streams, forwarded from just_audio.
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<bool> ensureMicrophonePermission() async {
    PermissionStatus status = await Permission.microphone.status;
    if (status.isGranted) return true;
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start recording. Returns false when mic permission is denied or a
  /// recording is already running. Stops automatically at [maxDuration].
  Future<bool> startRecording() async {
    if (_isRecording) return false;
    if (!await ensureMicrophonePermission()) return false;
    if (!await _recorder.hasPermission()) return false;

    final Directory dir = await getTemporaryDirectory();
    final String path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _currentPath = path;
    _isRecording = true;

    final DateTime startedAt = DateTime.now();
    _maxTimer?.cancel();
    _maxTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _elapsedController.add(DateTime.now().difference(startedAt));
    });
    // Auto-stop at the 5-minute cap.
    Timer(maxDuration, () {
      if (_isRecording) stopRecording();
    });
    return true;
  }

  /// Stop and keep the recording; returns the file, or null if not recording.
  Future<File?> stopRecording() async {
    if (!_isRecording) return null;
    _maxTimer?.cancel();
    final String? path = await _recorder.stop();
    _isRecording = false;
    _currentPath = path;
    if (path == null) return null;
    return File(path);
  }

  /// Cancel the recording and delete the partial file.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _maxTimer?.cancel();
    final String? path = await _recorder.stop();
    _isRecording = false;
    _currentPath = null;
    if (path != null) {
      final File file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  // ---- Playback ----

  Future<void> playFile(String path) async {
    await _player.setFilePath(path);
    await _player.play();
  }

  Future<void> playUrl(String url) async {
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> pause() async => _player.pause();

  Future<void> resume() async => _player.play();

  Future<void> seek(Duration position) async => _player.seek(position);

  Future<void> stopPlayback() async => _player.stop();

  Future<void> dispose() async {
    _maxTimer?.cancel();
    await _elapsedController.close();
    await _recorder.dispose();
    await _player.dispose();
  }
}
