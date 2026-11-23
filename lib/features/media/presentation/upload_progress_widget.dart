import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../data/media_service.dart';

/// Linear upload progress bar with percentage and a cancel button.
class UploadProgressWidget extends StatelessWidget {
  const UploadProgressWidget({
    super.key,
    required this.progress,
    this.onCancel,
    this.label = 'Uploading...',
  });

  final UploadProgress progress;
  final VoidCallback? onCancel;
  final String label;

  @override
  Widget build(BuildContext context) {
    final int percent = (progress.fraction * 100).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$label  $percent%',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.fraction,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.pink,
                  ),
                ),
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(
              icon: const Icon(Icons.close),
              color: AppColors.muted,
              onPressed: onCancel,
            ),
        ],
      ),
    );
  }
}
