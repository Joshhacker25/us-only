import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/message.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../media/presentation/media_picker_sheet.dart';
import '../../voice_notes/presentation/recorder_screen.dart';
import '../data/chat_repository.dart';
import 'chat_provider.dart';
import 'chat_search_screen.dart';
import 'message_bubble.dart';
import 'message_input.dart';

/// The couple's chat screen. The provider is created here from the ids the
/// caller passes in (Part A owns auth / the conversation id source).
class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.myUid,
    required this.partnerUid,
    required this.partnerName,
  });

  final String conversationId;
  final String myUid;
  final String partnerUid;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatProvider>(
      create: (_) => ChatProvider(
        repository: ChatRepository(),
        conversationId: conversationId,
        myUid: myUid,
        partnerUid: partnerUid,
      )..start(),
      child: _ChatView(partnerName: partnerName, partnerUid: partnerUid),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.partnerName, required this.partnerUid});

  final String partnerName;
  final String partnerUid;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<ChatProvider>().loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().markRead();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _showEditDialog(ChatProvider provider, Message message) async {
    _editController.text = message.text ?? '';
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Edit message',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: _editController,
            autofocus: true,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_editController.text),
              child: const Text(
                'Save',
                style: TextStyle(color: AppColors.pink),
              ),
            ),
          ],
        );
      },
    );
    if (result != null && result.trim().isNotEmpty) {
      await provider.editOwnMessage(message, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChatProvider provider = context.watch<ChatProvider>();
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.partnerName,
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
            Text(
              provider.partnerTyping ? 'typing...' : 'Only Us',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatSearchScreen(provider: provider),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (provider.isLoading)
            const Expanded(child: LoadingState(message: 'Loading messages...'))
          else if (provider.error != null)
            Expanded(
              child: ErrorState(
                message: provider.error!,
                onRetry: () => provider.start(),
              ),
            )
          else if (provider.messages.isEmpty)
            const Expanded(
              child: EmptyState(
                icon: Icons.favorite,
                title: 'Say hi to your love',
                subtitle: 'This is the start of your private conversation.',
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                itemCount: provider.messages.length +
                    (provider.isLoadingMore ? 1 : 0),
                itemBuilder: (BuildContext context, int index) {
                  if (index == provider.messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.pink,
                        ),
                      ),
                    );
                  }
                  final Message message = provider.messages[index];
                  Message? replyTo;
                  if (message.replyToId != null) {
                    for (final Message m in provider.messages) {
                      if (m.id == message.replyToId) {
                        replyTo = m;
                        break;
                      }
                    }
                  }
                  return MessageBubble(
                    message: message,
                    isMine: message.senderUid == provider.myUid,
                    replyTo: replyTo,
                    onReply: () => provider.setReplyTo(message),
                    onEdit: () => _showEditDialog(provider, message),
                    onDelete: () => provider.deleteOwnMessage(message),
                  );
                },
              ),
            ),
          MessageInput(
            replyTo: provider.replyTo,
            onCancelReply: () => provider.setReplyTo(null),
            onSendText: provider.sendText,
            onTypingChanged: provider.setTyping,
            onAttach: () {
              showMediaPickerSheet(
                context,
                conversationId: provider.conversationId,
                myUid: provider.myUid,
                onSent: (MessageType type, String url, {String? thumbnailUrl, int? durationMs, String? caption}) {
                  provider.sendMedia(
                    type: type,
                    mediaUrl: url,
                    thumbnailUrl: thumbnailUrl,
                    durationMs: durationMs,
                    caption: caption,
                  );
                },
              );
            },
            onVoicePressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecorderScreen(
                    conversationId: provider.conversationId,
                    myUid: provider.myUid,
                    onSent: (String url, int durationMs) {
                      provider.sendMedia(
                        type: MessageType.voice,
                        mediaUrl: url,
                        durationMs: durationMs,
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
