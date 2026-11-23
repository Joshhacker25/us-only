import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/message.dart';

/// Firestore access for the couple's chat.
///
/// Layout:
///   conversations/{conversationId}/messages/{messageId}
///   conversations/{conversationId}/typing/{uid}  (expires via `expiresAt`)
///
/// Typing indicators are best-effort: a typing document is written with an
/// expiry a few seconds in the future and is treated as stale after that.
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int pageSize = 50;
  static const Duration typingTtl = Duration(seconds: 8);

  CollectionReference<Map<String, dynamic>> _messagesRef(
    String conversationId,
  ) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');
  }

  /// Live stream of the newest [pageSize] messages, newest first.
  Stream<List<Message>> watchMessages(String conversationId) {
    return _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) =>
              snap.docs.map(Message.fromFirestore).toList(),
        );
  }

  /// One page of older messages, for pagination.
  /// Pass the oldest message currently loaded as [startAfter]; pass null
  /// for the first page.
  Future<List<Message>> fetchMessagesPage(
    String conversationId, {
    Message? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize);
    if (startAfter != null) {
      query = query.startAfter(<Object?>[Timestamp.fromDate(startAfter.createdAt)]);
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await query.get();
    return snap.docs.map(Message.fromFirestore).toList();
  }

  /// Send a message. Dedup: if a message with the same [clientId] already
  /// exists in this conversation, the existing document is returned and no
  /// second message is created.
  Future<Message> sendMessage({
    required String conversationId,
    required String senderUid,
    required MessageType type,
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    int? durationMs,
    String? replyToId,
    required String clientId,
  }) async {
    final CollectionReference<Map<String, dynamic>> ref =
        _messagesRef(conversationId);
    final QuerySnapshot<Map<String, dynamic>> existing = await ref
        .where('clientId', isEqualTo: clientId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return Message.fromFirestore(existing.docs.first);
    }

    final DateTime now = DateTime.now();
    final Message message = Message(
      id: '',
      conversationId: conversationId,
      senderUid: senderUid,
      type: type,
      text: text,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      durationMs: durationMs,
      replyToId: replyToId,
      createdAt: now,
      clientId: clientId,
      status: MessageStatus.sent,
    );
    final DocumentReference<Map<String, dynamic>> docRef = await ref.add(
      message.toFirestore(),
    );
    final DocumentSnapshot<Map<String, dynamic>> snap = await docRef.get();
    await _updateLastMessage(conversationId, message, senderUid);
    return Message.fromFirestore(snap);
  }

  Future<void> _updateLastMessage(
    String conversationId,
    Message message,
    String senderUid,
  ) async {
    final String preview = message.type == MessageType.text
        ? (message.text ?? '')
        : '[${message.type.name}]';
    await _firestore.collection('conversations').doc(conversationId).set(
      <String, dynamic>{
        'lastMessageText': preview,
        'lastMessageAt': Timestamp.fromDate(message.createdAt),
        'lastMessageSenderUid': senderUid,
        'updatedAt': Timestamp.fromDate(message.createdAt),
      },
      SetOptions(merge: true),
    );
  }

  /// Edit the text of your own message only. Throws [StateError] otherwise.
  Future<void> editMessage({
    required String conversationId,
    required Message message,
    required String myUid,
    required String newText,
  }) async {
    if (message.senderUid != myUid) {
      throw StateError('Only the sender can edit a message.');
    }
    if (message.type != MessageType.text) {
      throw StateError('Only text messages can be edited.');
    }
    await _messagesRef(conversationId).doc(message.id).update(
      <String, dynamic>{
        'text': newText,
        'editedAt': Timestamp.fromDate(DateTime.now()),
      },
    );
  }

  /// Delete your own message for everyone (tombstone, keeps the document).
  /// Throws [StateError] when the message is not yours.
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required Message message,
    required String myUid,
  }) async {
    if (message.senderUid != myUid) {
      throw StateError('Only the sender can delete a message.');
    }
    await _messagesRef(conversationId).doc(message.id).update(
      <String, dynamic>{
        'deletedForEveryone': true,
        'text': null,
        'mediaUrl': null,
        'thumbnailUrl': null,
      },
    );
  }

  /// Mark all messages from the partner as delivered (mine, received by
  /// partner) / read. [markRead] also sets readAt; otherwise only deliveredAt.
  Future<void> markMessagesRead({
    required String conversationId,
    required String partnerUid,
    bool markRead = true,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _messagesRef(
      conversationId,
    )
        .where('senderUid', isEqualTo: partnerUid)
        .where('readAt', isNull: true)
        .limit(100)
        .get();
    if (snap.docs.isEmpty) return;
    final WriteBatch batch = _firestore.batch();
    final DateTime now = DateTime.now();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      final Map<String, dynamic> update = <String, dynamic>{
        'deliveredAt': Timestamp.fromDate(now),
        'status': 'delivered',
      };
      if (markRead) {
        update['readAt'] = Timestamp.fromDate(now);
        update['status'] = 'read';
      }
      batch.update(doc.reference, update);
    }
    await batch.commit();
  }

  /// Mark one of my messages delivered (partner's device received it).
  Future<void> markDelivered({
    required String conversationId,
    required String messageId,
  }) async {
    await _messagesRef(conversationId).doc(messageId).update(
      <String, dynamic>{
        'deliveredAt': Timestamp.fromDate(DateTime.now()),
        'status': 'delivered',
      },
    );
  }

  // ---- Typing indicator ----

  Future<void> setTyping({
    required String conversationId,
    required String uid,
    required bool isTyping,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('typing')
        .doc(uid);
    if (!isTyping) {
      await ref.delete();
      return;
    }
    await ref.set(<String, dynamic>{
      'uid': uid,
      'isTyping': true,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(typingTtl)),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Live stream: true while the partner's typing document is unexpired.
  Stream<bool> watchPartnerTyping({
    required String conversationId,
    required String partnerUid,
  }) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('typing')
        .doc(partnerUid)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> doc) {
      if (!doc.exists) return false;
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      if (data['isTyping'] != true) return false;
      final Object? expiresAt = data['expiresAt'];
      if (expiresAt is Timestamp) {
        return expiresAt.toDate().isAfter(DateTime.now());
      }
      return false;
    });
  }

  // ---- Local search ----

  /// Search over the locally cached [messages] (text only, case-insensitive).
  /// Firestore has no full-text search; the provider keeps the loaded page
  /// in memory and this filters it.
  static List<Message> searchLocal(List<Message> messages, String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return <Message>[];
    return messages
        .where(
          (Message m) =>
              m.type == MessageType.text &&
              !m.deletedForEveryone &&
              (m.text ?? '').toLowerCase().contains(needle),
        )
        .toList();
  }
}
