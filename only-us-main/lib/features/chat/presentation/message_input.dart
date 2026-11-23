import 'dart:async';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/message.dart';
import '../../../shared/theme/app_colors.dart';

/// Composer: text field, emoji picker, reply preview, attach + voice buttons.
/// Typing state is reported through [onTypingChanged] (debounced by caller
/// if needed); the parent wires it to ChatProvider.setTyping.
class MessageInput extends StatefulWidget {
  const MessageInput({
    super.key,
    required this.onSendText,
    required this.onAttach,
    required this.onVoicePressed,
    required this.onTypingChanged,
    this.replyTo,
    this.onCancelReply,
  });

  final ValueChanged<String> onSendText;
  final VoidCallback onAttach;
  final VoidCallback onVoicePressed;
  final ValueChanged<bool> onTypingChanged;
  final Message? replyTo;
  final VoidCallback? onCancelReply;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  bool _showEmoji = false;
  bool _typing = false;
  Timer? _typingTimer;

  @override
  void dispose() {
    _controller.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    final bool typing = value.trim().isNotEmpty;
    if (typing != _typing) {
      _typing = typing;
      widget.onTypingChanged(typing);
    }
    _typingTimer?.cancel();
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 5), () {
        if (_typing) {
          _typing = false;
          widget.onTypingChanged(false);
        }
      });
    }
  }

  void _send() {
    final String text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    if (_typing) {
      _typing = false;
      widget.onTypingChanged(false);
    }
    setState(() => _showEmoji = false);
    widget.onSendText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.replyTo != null)
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                const Icon(Icons.reply, color: AppColors.pink, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.replyTo!.text ?? '[media]',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.lavender,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.muted,
                  onPressed: widget.onCancelReply,
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  color: AppColors.lavender,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _showEmoji = !_showEmoji);
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _send(),
                    minLines: 1,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Message your love...',
                      hintStyle: const TextStyle(color: AppColors.muted),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  color: AppColors.lavender,
                  onPressed: widget.onAttach,
                ),
                IconButton(
                  icon: const Icon(Icons.mic),
                  color: AppColors.pink,
                  onPressed: widget.onVoicePressed,
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                    onPressed: _send,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showEmoji)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              onEmojiSelected: (Category? category, Emoji emoji) {
                _controller.text += emoji.emoji;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              },
              config: const Config(
                emojiViewConfig: EmojiViewConfig(emojiSizeMax: 28),
              ),
            ),
          ),
      ],
    );
  }
}
