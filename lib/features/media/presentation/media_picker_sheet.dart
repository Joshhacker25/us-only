import 'dart:io';
import 'package:flutter/material.dart';
import '../../../shared/models/message.dart';
import '../../../shared/theme/app_colors.dart';
import '../data/media_service.dart';
import 'media_preview_screen.dart';
import 'upload_progress_widget.dart';

typedef MediaSentCallback = void Function(
  MessageType type,
  String url, {
  String? thumbnailUrl,
  int? durationMs,
  String? caption,
});

/// Bottom sheet: Photo / Video / Document. Picks a file, previews it, then
/// uploads to Firebase Storage under couples/{coupleId}/ with progress,
/// cancel and retry (see MediaService). Calls [onSent] with the download URL.
Future<void> showMediaPickerSheet(
  BuildContext context, {
  required String conversationId,
  required String myUid,
  required MediaSentCallback onSent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (BuildContext context) {
      return _MediaPickerSheet(
        coupleId: conversationId,
        onSent: onSent,
      );
    },
  );
}

class _MediaPickerSheet extends StatefulWidget {
  const _MediaPickerSheet({required this.coupleId, required this.onSent});

  final String coupleId;
  final MediaSentCallback onSent;

  @override
  State<_MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<_MediaPickerSheet> {
  final MediaService _service = MediaService();
  UploadProgress? _progress;
  String? _error;
  bool _uploading = false;

  MessageType _typeForKind(String kind) {
    switch (kind) {
      case 'video':
        return MessageType.video;
      case 'document':
        return MessageType.document;
      case 'photo':
      default:
        return MessageType.image;
    }
  }

  Future<void> _pickAndUpload(String kind) async {
    setState(() {
      _error = null;
      _progress = null;
    });
    try {
      File? file;
      if (kind == 'photo') {
        final dynamic picked = await _service.pickPhoto();
        if (picked == null) return;
        file = File(picked.path as String);
      } else if (kind == 'video') {
        final dynamic picked = await _service.pickVideo();
        if (picked == null) return;
        file = File(picked.path as String);
      } else {
        final dynamic picked = await _service.pickDocument();
        if (picked == null) return;
        final String? path = picked.path as String?;
        if (path == null) return;
        file = File(path);
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MediaPreviewScreen(
            file: file!,
            kind: kind,
            onSend: (File f, String k, String? caption) {
              _upload(f, kind, caption);
            },
          ),
        ),
      );
    } on MediaValidationException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _upload(File file, String kind, String? caption) async {
    setState(() {
      _uploading = true;
      _progress = const UploadProgress(bytesTransferred: 0, totalBytes: 1);
    });
    try {
      final String url = await _service.uploadFileWithRetry(
        coupleId: widget.coupleId,
        kind: kind,
        file: file,
        onProgress: (UploadProgress p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSent(_typeForKind(kind), url, caption: caption);
    } on MediaValidationException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_progress != null && _uploading)
              UploadProgressWidget(
                progress: _progress!,
                onCancel: () {
                  _service.cancelUpload();
                  setState(() => _uploading = false);
                },
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.photo, color: AppColors.pink),
              title: const Text(
                'Photo',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Max 50 MB',
                style: TextStyle(color: AppColors.muted),
              ),
              onTap: () => _pickAndUpload('photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: AppColors.pink),
              title: const Text(
                'Video',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Max 50 MB',
                style: TextStyle(color: AppColors.muted),
              ),
              onTap: () => _pickAndUpload('video'),
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: AppColors.pink,
              ),
              title: const Text(
                'Document',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Max 20 MB',
                style: TextStyle(color: AppColors.muted),
              ),
              onTap: () => _pickAndUpload('document'),
            ),
          ],
        ),
      ),
    );
  }
}
