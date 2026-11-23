import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/message.dart';
import '../../../shared/theme/app_colors.dart';
import '../../voice_notes/presentation/voice_note_bubble.dart';
import 'media_viewer_screen.dart';

String formatMessageTime(DateTime at) {
  final int hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final String minute = at.minute.toString().padLeft(2, '0');
  final String period = at.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// One chat bubble: text / image / video / document / voice, with reply,
/// edit/delete (own messages only), timestamps and read ticks.
/// Emoji render as normal text — no special handling is needed for them.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.replyTo,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  final Message message;
  final bool isMine;
  final Message? replyTo;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final Color bg = isMine ? AppColors.purple : AppColors.surfaceLight;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (replyTo != null && replyTo!.text != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(
                      left: BorderSide(color: AppColors.pink, width: 3),
                    ),
                  ),
                  child: Text(
                    replyTo!.text!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.lavender,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (message.deletedForEveryone)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.block, size: 14, color: AppColors.muted),
                    SizedBox(width: 6),
                    Text(
                      'This message was deleted',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              else
                _buildBody(context),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatMessageTime(message.createdAt),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  if (message.editedAt != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        'edited',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (isMine) ...<Widget>[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead
                          ? Icons.done_all
                          : Icons.done,
                      size: 15,
                      color: message.isRead
                          ? AppColors.pink
                          : AppColors.muted,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        if (message.mediaUrl == null) return const Text('Image unavailable');
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MediaViewerScreen(message: message),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: message.mediaUrl!,
              width: 220,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                width: 220,
                height: 140,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.pink),
                ),
              ),
              errorWidget: (_, __, ___) => const SizedBox(
                width: 220,
                height: 140,
                child: Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
        );
      case MessageType.video:
        if (message.mediaUrl == null) return const Text('Video unavailable');
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MediaViewerScreen(message: message),
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: message.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: message.thumbnailUrl!,
                        width: 220,
                        height: 140,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 220,
                        height: 140,
                        color: Colors.black45,
                        child: const Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
              ),
              const Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 48,
              ),
            ],
          ),
        );
      case MessageType.document:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.insert_drive_file, color: AppColors.lavender),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.text ?? 'Document',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        );
      case MessageType.voice:
        return VoiceNoteBubble(message: message, isMine: isMine);
      case MessageType.text:
        return Text(
          message.text ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        );
    }
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.reply, color: AppColors.lavender),
                title: const Text(
                  'Reply',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onReply?.call();
                },
              ),
              if (isMine && message.type == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.edit, color: AppColors.lavender),
                  title: const Text(
                    'Edit',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onEdit?.call();
                  },
                ),
              if (isMine)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.error),
                  title: const Text(
                    'Delete for everyone',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete?.call();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
