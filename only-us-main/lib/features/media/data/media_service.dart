import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Media limits (documented, enforced in [validateFile]):
/// - photos and videos: max 50 MB
/// - documents: max 20 MB
class MediaLimits {
  MediaLimits._();

  static const int maxPhotoVideoBytes = 50 * 1024 * 1024;
  static const int maxDocumentBytes = 20 * 1024 * 1024;

  static const List<String> photoExtensions = <String>[
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic',
  ];
  static const List<String> videoExtensions = <String>[
    'mp4', 'mov', 'mkv', 'webm',
  ];
  static const List<String> documentExtensions = <String>[
    'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx', 'zip',
  ];
}

class MediaValidationException implements Exception {
  const MediaValidationException(this.message);

  final String message;

  @override
  String toString() => 'MediaValidationException: $message';
}

class UploadProgress {
  const UploadProgress({
    required this.bytesTransferred,
    required this.totalBytes,
  });

  final int bytesTransferred;
  final int totalBytes;

  double get fraction =>
      totalBytes <= 0 ? 0 : bytesTransferred / totalBytes;
}

/// Picking, validation, upload (with progress / cancel / retry) and local
/// cache / download for chat media. Files live under
/// `couples/{coupleId}/chat/{kind}/{timestamp}_{filename}` in Firebase Storage.
class MediaService {
  MediaService({FirebaseStorage? storage, ImagePicker? picker})
      : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseStorage _storage;
  final ImagePicker _picker;
  UploadTask? _activeTask;

  // ---- Picking ----

  Future<XFile?> pickPhoto({bool fromCamera = false}) async {
    return _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
  }

  Future<XFile?> pickVideo({bool fromCamera = false}) async {
    return _picker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
  }

  Future<PlatformFile?> pickDocument() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: MediaLimits.documentExtensions,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  // ---- Validation ----

  /// Validates [file] for [kind] ('photo', 'video' or 'document').
  /// Throws [MediaValidationException] on a bad type or oversize file.
  Future<void> validateFile(File file, String kind) async {
    final int size = await file.length();
    final String ext = file.path.split('.').last.toLowerCase();
    switch (kind) {
      case 'photo':
        if (!MediaLimits.photoExtensions.contains(ext)) {
          throw const MediaValidationException('Unsupported photo type.');
        }
        if (size > MediaLimits.maxPhotoVideoBytes) {
          throw const MediaValidationException(
            'Photo is over the 50 MB limit.',
          );
        }
      case 'video':
        if (!MediaLimits.videoExtensions.contains(ext)) {
          throw const MediaValidationException('Unsupported video type.');
        }
        if (size > MediaLimits.maxPhotoVideoBytes) {
          throw const MediaValidationException(
            'Video is over the 50 MB limit.',
          );
        }
      case 'voice':
        if (ext != 'm4a' && ext != 'aac' && ext != 'mp3' && ext != 'wav') {
          throw const MediaValidationException('Unsupported voice note type.');
        }
        if (size > MediaLimits.maxPhotoVideoBytes) {
          throw const MediaValidationException(
            'Voice note is over the 50 MB limit.',
          );
        }
      case 'document':
        if (!MediaLimits.documentExtensions.contains(ext)) {
          throw const MediaValidationException('Unsupported document type.');
        }
        if (size > MediaLimits.maxDocumentBytes) {
          throw const MediaValidationException(
            'Document is over the 20 MB limit.',
          );
        }
      default:
        throw const MediaValidationException('Unknown media kind.');
    }
  }

  // ---- Upload ----

  String _storagePath(String coupleId, String kind, String fileName) {
    final String safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return 'couples/$coupleId/chat/$kind/'
        '${DateTime.now().millisecondsSinceEpoch}_$safe';
  }

  /// Upload [file]; emits progress snapshots. Keep the returned task's
  /// [UploadTask] via [cancelUpload] to cancel. Returns the download URL.
  Future<String> uploadFile({
    required String coupleId,
    required String kind,
    required File file,
    String? fileName,
    void Function(UploadProgress progress)? onProgress,
  }) async {
    await validateFile(file, kind);
    final String name = fileName ?? file.path.split('/').last;
    final Reference ref = _storage.ref().child(
      _storagePath(coupleId, kind, name),
    );
    final UploadTask task = ref.putFile(file);
    _activeTask = task;
    final StreamSubscription<TaskSnapshot> sub =
        task.snapshotEvents.listen((TaskSnapshot snapshot) {
      onProgress?.call(
        UploadProgress(
          bytesTransferred: snapshot.bytesTransferred,
          totalBytes: snapshot.totalBytes,
        ),
      );
    });
    try {
      final TaskSnapshot snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } finally {
      await sub.cancel();
      if (_activeTask == task) _activeTask = null;
    }
  }

  /// Retry an upload up to [maxAttempts] times (default 3).
  Future<String> uploadFileWithRetry({
    required String coupleId,
    required String kind,
    required File file,
    String? fileName,
    void Function(UploadProgress progress)? onProgress,
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await uploadFile(
          coupleId: coupleId,
          kind: kind,
          file: file,
          fileName: fileName,
          onProgress: onProgress,
        );
      } catch (e) {
        lastError = e;
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }
    throw lastError ?? StateError('Upload failed.');
  }

  Future<void> cancelUpload() async {
    await _activeTask?.cancel();
    _activeTask = null;
  }

  // ---- Local cache / download ----

  /// Local cache directory for downloaded media.
  Future<Directory> get cacheDir async {
    final Directory dir = await getTemporaryDirectory();
    final Directory mediaDir = Directory('${dir.path}/only_us_media');
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    return mediaDir;
  }

  /// Download [url] to the local cache and return the local file.
  /// Returns the cached file immediately when it already exists.
  Future<File> downloadToCache(String url, {String? fileName}) async {
    final Directory dir = await cacheDir;
    final String name = fileName ??
        'media_${url.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}';
    final File file = File('${dir.path}/$name');
    if (await file.exists()) return file;
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request =
          await client.getUrl(Uri.parse(url));
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed with status ${response.statusCode}',
        );
      }
      final IOSink sink = file.openWrite();
      await sink.addStream(response);
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  /// Clear the in-memory image cache for one URL (cached_network_image).
  Future<void> evictFromImageCache(String url) async {
    await CachedNetworkImageProvider(url).evict();
  }

  @visibleForTesting
  static bool isWithinLimit(int bytes, String kind) {
    if (kind == 'document') return bytes <= MediaLimits.maxDocumentBytes;
    return bytes <= MediaLimits.maxPhotoVideoBytes;
  }
}
