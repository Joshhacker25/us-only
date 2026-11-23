import 'dart:io';
import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';

/// Preview a picked photo / video / document before sending, with an
/// optional caption field and a Send button.
class MediaPreviewScreen extends StatefulWidget {
  const MediaPreviewScreen({
    super.key,
    required this.file,
    required this.kind,
    required this.onSend,
  });

  final File file;
  final String kind; // 'photo' | 'video' | 'document'
  final void Function(File file, String kind, String? caption) onSend;

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String fileName = widget.file.path.split('/').last;
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.midnight,
        title: Text(
          widget.kind == 'document' ? 'Send document' : 'Preview',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: widget.kind == 'photo'
                  ? Image.file(widget.file, fit: BoxFit.contain)
                  : widget.kind == 'video'
                      ? const Icon(
                          Icons.videocam,
                          color: AppColors.lavender,
                          size: 96,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.insert_drive_file,
                              color: AppColors.lavender,
                              size: 96,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              fileName,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: const TextStyle(color: AppColors.muted),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                    onPressed: () {
                      final String caption = _captionController.text.trim();
                      widget.onSend(
                        widget.file,
                        widget.kind,
                        caption.isEmpty ? null : caption,
                      );
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
