/// Thinking-of-you hearts: gentle, throttled, and respectful.
///
/// THROTTLING (documented limits — enforced client-side here; the
/// Firestore rules / Cloud Function owned by Part A should enforce the
/// same limits server-side so a modified client cannot spam):
///   * Max 1 heart per 10 seconds.
///   * Max 20 hearts per rolling hour.
///
/// QUIET HOURS + OPT-OUT:
///   * [ThinkingOfYouSettings] holds the partner's quiet-hours window
///     and whether they opted out of heart notifications entirely.
///   * When quiet hours are active, hearts are still delivered in-app
///     (they appear in the romantic-events history) but no push
///     notification is triggered — the push decision is made by the
///     notification sender (Part A), which must read these settings.
///   * When the partner opted out, hearts are not sent at all from this
///     device; the UI shows the opt-out state instead of a send button.
library;

import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../hugs_kisses/romantic_event_service.dart';

/// Per-user settings for receiving hearts.
class ThinkingOfYouSettings {
  const ThinkingOfYouSettings({
    this.heartsOptedOut = false,
    this.quietHoursEnabled = false,
    this.quietStartHour = 22,
    this.quietStartMinute = 0,
    this.quietEndHour = 8,
    this.quietEndMinute = 0,
  });

  factory ThinkingOfYouSettings.fromMap(Map<String, dynamic> map) {
    return ThinkingOfYouSettings(
      heartsOptedOut: map['heartsOptedOut'] as bool? ?? false,
      quietHoursEnabled: map['quietHoursEnabled'] as bool? ?? false,
      quietStartHour: map['quietStartHour'] as int? ?? 22,
      quietStartMinute: map['quietStartMinute'] as int? ?? 0,
      quietEndHour: map['quietEndHour'] as int? ?? 8,
      quietEndMinute: map['quietEndMinute'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'heartsOptedOut': heartsOptedOut,
        'quietHoursEnabled': quietHoursEnabled,
        'quietStartHour': quietStartHour,
        'quietStartMinute': quietStartMinute,
        'quietEndHour': quietEndHour,
        'quietEndMinute': quietEndMinute,
      };

  /// True when hearts should not be sent at all.
  final bool heartsOptedOut;

  final bool quietHoursEnabled;

  /// Quiet window start (local time, 24h clock).
  final int quietStartHour;
  final int quietStartMinute;

  /// Quiet window end (local time, 24h clock). May be earlier than the
  /// start when the window crosses midnight (e.g. 22:00–08:00).
  final int quietEndHour;
  final int quietEndMinute;

  /// True when [moment] (local time) falls inside the quiet window.
  bool isQuietAt(DateTime moment) {
    if (!quietHoursEnabled) return false;
    final nowMinutes = moment.hour * 60 + moment.minute;
    final start = quietStartHour * 60 + quietStartMinute;
    final end = quietEndHour * 60 + quietEndMinute;
    if (start == end) return false;
    if (start < end) return nowMinutes >= start && nowMinutes < end;
    // Window crosses midnight.
    return nowMinutes >= start || nowMinutes < end;
  }
}

/// Result of attempting to send a heart.
enum HeartSendResult {
  sent,
  throttled,
  optedOut,
}

/// Sends thinking-of-you hearts with throttling, honouring the
/// partner's quiet-hours and opt-out settings.
class ThinkingOfYouService {
  ThinkingOfYouService({
    RomanticEventService? events,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _events = events ?? RomanticEventService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final RomanticEventService _events;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Max 1 heart per 10 seconds.
  static const Duration minInterval = Duration(seconds: 10);

  /// Max 20 hearts per rolling hour.
  static const int maxPerHour = 20;
  static const Duration hourlyWindow = Duration(hours: 1);

  DateTime? _lastSentAt;
  final Queue<DateTime> _sentInWindow = Queue<DateTime>();

  String get _myUid => _auth.currentUser?.uid ?? '';

  /// Reads the partner's thinking-of-you settings from their user doc.
  /// Path: `users/{partnerUid}/settings/thinkingOfYou`.
  Future<ThinkingOfYouSettings> loadPartnerSettings(
    String partnerUid,
  ) async {
    final doc = await _firestore
        .collection('users')
        .doc(partnerUid)
        .collection('settings')
        .doc('thinkingOfYou')
        .get();
    if (!doc.exists) return const ThinkingOfYouSettings();
    return ThinkingOfYouSettings.fromMap(doc.data() ?? const {});
  }

  /// Saves my own thinking-of-you settings.
  Future<void> saveMySettings(ThinkingOfYouSettings settings) async {
    final uid = _myUid;
    if (uid.isEmpty) {
      throw StateError('ThinkingOfYouService: no signed-in user.');
    }
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('thinkingOfYou')
        .set(settings.toMap(), SetOptions(merge: true));
  }

  /// Whether a heart may be sent right now (throttle only).
  bool get canSendNow {
    final now = DateTime.now();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!) < minInterval) {
      return false;
    }
    _pruneWindow(now);
    return _sentInWindow.length < maxPerHour;
  }

  void _pruneWindow(DateTime now) {
    while (_sentInWindow.isNotEmpty &&
        now.difference(_sentInWindow.first) > hourlyWindow) {
      _sentInWindow.removeFirst();
    }
  }

  /// Sends a heart, honouring throttle + the partner's opt-out.
  /// Returns [HeartSendResult.throttled] when the rate limit is hit
  /// (the UI should show a gentle "slow down" hint, not an error) and
  /// [HeartSendResult.optedOut] when the partner opted out of hearts.
  /// The caller passes the partner's settings, loaded via
  /// [loadPartnerSettings]; if settings cannot be loaded, the send
  /// proceeds (fail-open for delivery, fail-closed for notifications —
  /// the notification sender must re-check settings server-side).
  Future<HeartSendResult> sendHeart({
    required String coupleId,
    required String partnerUid,
    ThinkingOfYouSettings? partnerSettings,
  }) async {
    if (partnerSettings?.heartsOptedOut == true) {
      return HeartSendResult.optedOut;
    }
    if (!canSendNow) return HeartSendResult.throttled;
    await _events.sendEvent(
      coupleId: coupleId,
      type: RomanticEventType.heart,
    );
    final now = DateTime.now();
    _lastSentAt = now;
    _sentInWindow.addLast(now);
    return HeartSendResult.sent;
  }
}
