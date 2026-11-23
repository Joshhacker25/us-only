import 'package:flutter/material.dart';
import '../../../shared/models/message.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';
import 'chat_provider.dart';
import 'message_bubble.dart';

/// Search over the messages already loaded in memory (see
/// ChatRepository.searchLocal — Firestore has no full-text search).
class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key, required this.provider});

  final ChatProvider provider;

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Message> _results = <Message>[];
  bool _searched = false;

  void _runSearch(String query) {
    setState(() {
      _results = widget.provider.search(query);
      _searched = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _runSearch,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search messages...',
            hintStyle: TextStyle(color: AppColors.muted),
            border: InputBorder.none,
          ),
        ),
      ),
      body: !_searched
          ? const EmptyState(
              icon: Icons.search,
              title: 'Search your conversation',
              subtitle: 'Search covers the messages already loaded on screen.',
            )
          : _results.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'No messages found',
                  subtitle: 'Try a different word.',
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Message message = _results[index];
                    return MessageBubble(
                      message: message,
                      isMine:
                          message.senderUid == widget.provider.myUid,
                    );
                  },
                ),
    );
  }
}
