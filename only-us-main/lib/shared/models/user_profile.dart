import 'package:cloud_firestore/cloud_firestore.dart';

/// Profile for one of the two people in the couple.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    this.nickname,
    this.avatarUrl,
    this.relationshipStartDate,
    this.isOnline = false,
    this.lastSeenAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    DateTime? parseDate(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      nickname: data['nickname'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      relationshipStartDate: parseDate(data['relationshipStartDate']),
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeenAt: parseDate(data['lastSeenAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'displayName': displayName,
      'nickname': nickname,
      'avatarUrl': avatarUrl,
      'relationshipStartDate': relationshipStartDate == null
          ? null
          : Timestamp.fromDate(relationshipStartDate!),
      'isOnline': isOnline,
      'lastSeenAt':
          lastSeenAt == null ? null : Timestamp.fromDate(lastSeenAt!),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? nickname,
    String? avatarUrl,
    DateTime? relationshipStartDate,
    bool? isOnline,
    DateTime? lastSeenAt,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      relationshipStartDate:
          relationshipStartDate ?? this.relationshipStartDate,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  /// Display name shown in chat: nickname wins over display name.
  String get shownName =>
      (nickname != null && nickname!.trim().isNotEmpty)
          ? nickname!.trim()
          : displayName;

  /// Days together, computed locally from [relationshipStartDate].
  /// Returns null when no start date has been set.
  int? get daysTogether {
    if (relationshipStartDate == null) return null;
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(
      relationshipStartDate!.year,
      relationshipStartDate!.month,
      relationshipStartDate!.day,
    );
    final DateTime today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays;
  }

  final String uid;
  final String displayName;
  final String? nickname;
  final String? avatarUrl;
  final DateTime? relationshipStartDate;
  final bool isOnline;
  final DateTime? lastSeenAt;
}
