import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../shared/models/message.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/loading_state.dart';

/// Full-screen photo / video viewer with pinch zoom for photos.
/// Video plays with the standard video_player controls.
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({super.key, required this.message});

  final Message message;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.video &&
        widget.message.mediaUrl != null) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.message.mediaUrl!))
            ..initialize().then((_) {
              if (mounted) {
                setState(() {});
                _videoController?.play();
              }
            });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Message message = widget.message;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          message.type == MessageType.video ? 'Video' : 'Photo',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: message.type == MessageType.video
            ? _buildVideo()
            : InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: message.mediaUrl == null
                    ? const Text(
                        'Media unavailable',
                        style: TextStyle(color: Colors.white),
                      )
                    : CachedNetworkImage(
                        imageUrl: message.mediaUrl!,
                        placeholder: (_, __) => const LoadingState(),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
              ),
      ),
    );
  }

  Widget _buildVideo() {
    final VideoPlayerController? controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const LoadingState(message: 'Loading video...');
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        const SizedBox(height: 16),
        IconButton(
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: AppColors.pink,
            size: 40,
          ),
          onPressed: () {
            setState(() {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            });
          },
        ),
        VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          colors: const VideoProgressColors(
            playedColor: AppColors.pink,
            backgroundColor: Colors.white24,
          ),
        ),
      ],
    );
  }
}
