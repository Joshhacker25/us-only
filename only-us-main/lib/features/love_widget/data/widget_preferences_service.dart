/// Home-screen love widget preferences.
///
/// The widget shows: partner nickname, days together, an optional sweet
/// note, and the last heart received. [WidgetPreferences.privacyMode]
/// hides the note (and the last-heart time) whenever the phone is
/// locked — the native widget reads these same values from
/// SharedPreferences ("only_us_widget"), so this service keeps Firestore
/// and local storage in sync and then asks the native side to refresh
/// the widget (see [notifyWidgetChanged]).
///
/// The widget itself is native (Kotlin AppWidget, Part C) and reads only
/// what is written here — it never talks to Firestore directly.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the home-screen widget shows.
class WidgetPreferences {
  const WidgetPreferences({
    this.showNickname = true,
    this.showDays = true,
    this.showNote = true,
    this.showLastHeart = true,
    this.privacyMode = true,
    this.nickname = '',
    this.sweetNote = '',
    this.anniversary,
  });

  factory WidgetPreferences.fromMap(Map<String, dynamic> map) {
    return WidgetPreferences(
      showNickname: map['showNickname'] as bool? ?? true,
      showDays: map['showDays'] as bool? ?? true,
      showNote: map['showNote'] as bool? ?? true,
      showLastHeart: map['showLastHeart'] as bool? ?? true,
      privacyMode: map['privacyMode'] as bool? ?? true,
      nickname: map['nickname'] as String? ?? '',
      sweetNote: map['sweetNote'] as String? ?? '',
      anniversary: (map['anniversary'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'showNickname': showNickname,
        'showDays': showDays,
        'showNote': showNote,
        'showLastHeart': showLastHeart,
        'privacyMode': privacyMode,
        'nickname': nickname,
        'sweetNote': sweetNote,
        'anniversary': anniversary == null
            ? null
            : Timestamp.fromDate(anniversary!),
      };

  /// Show the partner's nickname on the widget.
  final bool showNickname;

  /// Show the days-together counter.
  final bool showDays;

  /// Show the sweet note. Hidden whenever [privacyMode] applies.
  final bool showNote;

  /// Show when the last heart arrived.
  final bool showLastHeart;

  /// When true, the note (and last-heart time) are hidden on the lock
  /// screen / whenever the widget cannot confirm the phone is unlocked.
  /// Default true — privacy first.
  final bool privacyMode;

  final String nickname;
  final String sweetNote;

  /// Anniversary / together-since date the days counter counts from.
  final DateTime? anniversary;

  WidgetPreferences copyWith({
    bool? showNickname,
    bool? showDays,
    bool? showNote,
    bool? showLastHeart,
    bool? privacyMode,
    String? nickname,
    String? sweetNote,
    DateTime? anniversary,
  }) {
    return WidgetPreferences(
      showNickname: showNickname ?? this.showNickname,
      showDays: showDays ?? this.showDays,
      showNote: showNote ?? this.showNote,
      showLastHeart: showLastHeart ?? this.showLastHeart,
      privacyMode: privacyMode ?? this.privacyMode,
      nickname: nickname ?? this.nickname,
      sweetNote: sweetNote ?? this.sweetNote,
      anniversary: anniversary ?? this.anniversary,
    );
  }
}

class WidgetPreferencesService {
  WidgetPreferencesService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// MethodChannel the native widget side listens on. Invoking
  /// `updateWidget` makes MainActivity (Part A) do two things:
  ///   1. Write the passed arguments into SharedPreferences
  ///      "only_us_widget" (the file the native widget reads — Flutter's
  ///      shared_preferences plugin uses its own file, so the Dart side
  ///      cannot write the widget's file directly).
  ///   2. Broadcast `com.onlyus.app.widget.ACTION_UPDATE_WIDGET`, which
  ///      the AppWidgetProvider handles.
  /// See android/WIDGET_SETUP_NOTE.md for the exact MainActivity code.
  static const MethodChannel _widgetChannel =
      MethodChannel('com.onlyus.app/widget');

  /// SharedPreferences file the native widget reads.
  static const String widgetPrefsName = 'only_us_widget';

  String get _myUid => _auth.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> _doc(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('widget_preferences')
        .doc(_myUid);
  }

  /// Loads preferences: Firestore first, local cache as fallback.
  Future<WidgetPreferences> load(String coupleId) async {
    try {
      final snap = await _doc(coupleId).get();
      if (snap.exists) {
        final prefs = WidgetPreferences.fromMap(snap.data() ?? const {});
        await _writeLocal(prefs);
        return prefs;
      }
    } catch (_) {
      // Offline — fall through to the local cache.
    }
    return loadLocal();
  }

  /// Loads the local cache only (what the widget actually displays).
  Future<WidgetPreferences> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(widgetPrefsName);
    if (raw == null) return const WidgetPreferences();
    try {
      return WidgetPreferences.fromMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const WidgetPreferences();
    }
  }

  /// Saves to Firestore + local cache, then refreshes the widget.
  Future<void> save(String coupleId, WidgetPreferences prefs) async {
    await _writeLocal(prefs);
    try {
      await _doc(coupleId).set(prefs.toMap(), SetOptions(merge: true));
    } catch (_) {
      // Offline: local cache still updates the widget now; Firestore
      // syncs when the app next saves with connectivity.
    }
    await notifyWidgetChanged(prefs);
  }

  /// Updates the last-heart timestamp shown on the widget.
  Future<void> updateLastHeart(String coupleId, DateTime when) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${widgetPrefsName}_last_heart',
      when.toIso8601String(),
    );
    await notifyWidgetChanged(
      await loadLocal(),
      lastHeartIso: when.toIso8601String(),
    );
  }

  Future<void> _writeLocal(WidgetPreferences prefs) async {
    final local = await SharedPreferences.getInstance();
    // Local cache for the Flutter side. The native widget's
    // SharedPreferences file ("only_us_widget") is written by
    // MainActivity from the MethodChannel arguments — see
    // [notifyWidgetChanged] and android/WIDGET_SETUP_NOTE.md.
    await local.setBool('showNickname', prefs.showNickname);
    await local.setBool('showDays', prefs.showDays);
    await local.setBool('showNote', prefs.showNote);
    await local.setBool('showLastHeart', prefs.showLastHeart);
    await local.setBool('privacyMode', prefs.privacyMode);
    await local.setString('nickname', prefs.nickname);
    await local.setString('sweetNote', prefs.sweetNote);
    if (prefs.anniversary != null) {
      await local.setString(
        'anniversary',
        prefs.anniversary!.toIso8601String(),
      );
    }
    // Keep a JSON copy too, for the Flutter side's loadLocal().
    await local.setString(widgetPrefsName, jsonEncode(prefs.toMap()));
  }

  /// Asks the native side to redraw the widget now, passing the current
  /// preferences so MainActivity can write them into SharedPreferences
  /// "only_us_widget" before broadcasting the update.
  Future<void> notifyWidgetChanged(
    WidgetPreferences prefs, {
    String? lastHeartIso,
  }) async {
    try {
      await _widgetChannel.invokeMethod('updateWidget', <String, dynamic>{
        'showNickname': prefs.showNickname,
        'showDays': prefs.showDays,
        'showNote': prefs.showNote,
        'showLastHeart': prefs.showLastHeart,
        'privacyMode': prefs.privacyMode,
        'nickname': prefs.nickname,
        'sweetNote': prefs.sweetNote,
        'anniversary': prefs.anniversary?.toIso8601String(),
        'lastHeart': lastHeartIso,
      });
    } on PlatformException {
      // MethodChannel is wired in MainActivity (Part A). If it is not
      // there yet, the widget still refreshes on its next onUpdate.
    } on MissingPluginException {
      // Same as above — safe to ignore.
    }
  }
}
