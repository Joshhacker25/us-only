import 'package:cloud_firestore/cloud_firestore.dart';

/// The couple's single conversation. Only Us has exactly one conversation
/// per couple, between the two allowlisted UIDs.
class Conversation {
  const Conversation({
    required this.id,
    required this.participantUids,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastMessageSenderUid,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    DateTime parseTs(Object? value, {required DateTime fallback}) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? fallback;
      return fallback;
    }

    final DateTime now = DateTime.now();
    final List<dynamic> raw = data['participantUids'] as List<dynamic>? ?? <dynamic>[];
    return Conversation(
      id: doc.id,
      participantUids: raw.map((dynamic e) => e.toString()).toList(),
      lastMessageText: data['lastMessageText'] as String?,
      lastMessageAt: data['lastMessageAt'] == null
          ? null
          : parseTs(data['lastMessageAt'], fallback: now),
      lastMessageSenderUid: data['lastMessageSenderUid'] as String?,
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      createdAt: parseTs(data['createdAt'], fallback: now),
      updatedAt: parseTs(data['updatedAt'], fallback: now),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'participantUids': participantUids,
      'lastMessageText': lastMessageText,
      'lastMessageAt':
          lastMessageAt == null ? null : Timestamp.fromDate(lastMessageAt!),
      'lastMessageSenderUid': lastMessageSenderUid,
      'unreadCount': unreadCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// The other participant in this two-person conversation.
  String? partnerUid(String myUid) {
    for (final String uid in participantUids) {
      if (uid != myUid) return uid;
    }
    return null;
  }

  final String id;
  final List<String> participantUids;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderUid;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}
