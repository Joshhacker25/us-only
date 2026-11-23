import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../shared/models/message.dart';
import '../data/chat_repository.dart';

/// Chat state for the couple's one conversation, via Provider/ChangeNotifier.
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required ChatRepository repository,
    required String conversationId,
    required String myUid,
    required String partnerUid,
  })  : _repository = repository,
        _conversationId = conversationId,
        _myUid = myUid,
        _partnerUid = partnerUid;

  final ChatRepository _repository;
  final String _conversationId;
  final String _myUid;
  final String _partnerUid;

  List<Message> _messages = <Message>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  bool _partnerTyping = false;
  Message? _replyTo;
  StreamSubscription<List<Message>>? _messagesSub;
  StreamSubscription<bool>? _typingSub;

  List<Message> get messages => List<Message>.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get partnerTyping => _partnerTyping;
  Message? get replyTo => _replyTo;
  String get conversationId => _conversationId;
  String get myUid => _myUid;

  void start() {
    _messagesSub = _repository.watchMessages(_conversationId).listen(
      (List<Message> incoming) {
        _messages = incoming;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _isLoading = false;
        _error = e.toString();
        notifyListeners();
      },
    );
    _typingSub = _repository
        .watchPartnerTyping(
          conversationId: _conversationId,
          partnerUid: _partnerUid,
        )
        .listen((bool typing) {
      _partnerTyping = typing;
      notifyListeners();
    });
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final List<Message> older = await _repository.fetchMessagesPage(
        _conversationId,
        startAfter: _messages.last,
      );
      if (older.length < ChatRepository.pageSize) _hasMore = false;
      final Set<String> seen = _messages.map((Message m) => m.id).toSet();
      _messages = <Message>[
        ..._messages,
        ...older.where((Message m) => !seen.contains(m.id)),
      ];
    } on FirebaseException catch (e) {
      _error = e.message ?? e.code;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  String _newClientId() =>
      '${DateTime.now().microsecondsSinceEpoch}-$_myUid';

  Future<void> sendText(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final Message? reply = _replyTo;
    _replyTo = null;
    notifyListeners();
    await _repository.sendMessage(
      conversationId: _conversationId,
      senderUid: _myUid,
      type: MessageType.text,
      text: trimmed,
      replyToId: reply?.id,
      clientId: _newClientId(),
    );
  }

  Future<void> sendMedia({
    required MessageType type,
    required String mediaUrl,
    String? thumbnailUrl,
    int? durationMs,
    String? caption,
  }) async {
    await _repository.sendMessage(
      conversationId: _conversationId,
      senderUid: _myUid,
      type: type,
      text: caption,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      durationMs: durationMs,
      clientId: _newClientId(),
    );
  }

  Future<void> editOwnMessage(Message message, String newText) async {
    await _repository.editMessage(
      conversationId: _conversationId,
      message: message,
      myUid: _myUid,
      newText: newText.trim(),
    );
  }

  Future<void> deleteOwnMessage(Message message) async {
    await _repository.deleteMessageForEveryone(
      conversationId: _conversationId,
      message: message,
      myUid: _myUid,
    );
  }

  Future<void> markRead() async {
    await _repository.markMessagesRead(
      conversationId: _conversationId,
      partnerUid: _partnerUid,
    );
  }

  Future<void> setTyping(bool isTyping) async {
    await _repository.setTyping(
      conversationId: _conversationId,
      uid: _myUid,
      isTyping: isTyping,
    );
  }

  void setReplyTo(Message? message) {
    _replyTo = message;
    notifyListeners();
  }

  List<Message> search(String query) =>
      ChatRepository.searchLocal(_messages, query);

  @override
  void dispose() {
    _messagesSub?.cancel();
    _typingSub?.cancel();
    super.dispose();
  }
}
