import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, document, voice }

enum MessageStatus { sending, sent, delivered, read, failed }

MessageType messageTypeFromString(String value) {
  return MessageType.values.firstWhere(
    (MessageType e) => e.name == value,
    orElse: () => MessageType.text,
  );
}

MessageStatus messageStatusFromString(String value) {
  return MessageStatus.values.firstWhere(
    (MessageStatus e) => e.name == value,
    orElse: () => MessageStatus.sent,
  );
}

/// A single chat message in the couple's one conversation.
/// `clientId` is a locally generated UUID used for send dedup: a retry with
/// the same clientId must not create a second document.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderUid,
    required this.type,
    this.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.durationMs,
    this.replyToId,
    this.editedAt,
    this.deletedForEveryone = false,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
    required this.clientId,
    this.status = MessageStatus.sent,
  });

  factory Message.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    DateTime parseTs(Object? value, {required DateTime fallback}) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? fallback;
      return fallback;
    }

    final DateTime now = DateTime.now();
    return Message(
      id: doc.id,
      conversationId: data['conversationId'] as String? ?? '',
      senderUid: data['senderUid'] as String? ?? '',
      type: messageTypeFromString(data['type'] as String? ?? 'text'),
      text: data['text'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      durationMs: (data['durationMs'] as num?)?.toInt(),
      replyToId: data['replyToId'] as String?,
      editedAt: data['editedAt'] == null
          ? null
          : parseTs(data['editedAt'], fallback: now),
      deletedForEveryone: data['deletedForEveryone'] as bool? ?? false,
      createdAt: parseTs(data['createdAt'], fallback: now),
      deliveredAt: data['deliveredAt'] == null
          ? null
          : parseTs(data['deliveredAt'], fallback: now),
      readAt: data['readAt'] == null
          ? null
          : parseTs(data['readAt'], fallback: now),
      clientId: data['clientId'] as String? ?? doc.id,
      status: messageStatusFromString(data['status'] as String? ?? 'sent'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'conversationId': conversationId,
      'senderUid': senderUid,
      'type': type.name,
      'text': text,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'durationMs': durationMs,
      'replyToId': replyToId,
      'editedAt': editedAt == null ? null : Timestamp.fromDate(editedAt!),
      'deletedForEveryone': deletedForEveryone,
      'createdAt': Timestamp.fromDate(createdAt),
      'deliveredAt': deliveredAt == null ? null : Timestamp.fromDate(deliveredAt!),
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
      'clientId': clientId,
      'status': status.name,
    };
  }

  Message copyWith({
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    int? durationMs,
    String? replyToId,
    DateTime? editedAt,
    bool? deletedForEveryone,
    DateTime? deliveredAt,
    DateTime? readAt,
    MessageStatus? status,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderUid: senderUid,
      type: type,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      replyToId: replyToId ?? this.replyToId,
      editedAt: editedAt ?? this.editedAt,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      clientId: clientId,
      status: status ?? this.status,
    );
  }

  bool get isMedia =>
      type == MessageType.image ||
      type == MessageType.video ||
      type == MessageType.document ||
      type == MessageType.voice;

  bool get isRead => readAt != null || status == MessageStatus.read;
  bool get isDelivered => deliveredAt != null || isRead;

  final String id;
  final String conversationId;
  final String senderUid;
  final MessageType type;
  final String? text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? durationMs;
  final String? replyToId;
  final DateTime? editedAt;
  final bool deletedForEveryone;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String clientId;
  final MessageStatus status;
}
