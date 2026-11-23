/// Push + local notifications — Part A.
///
/// Firebase Cloud Messaging for messages / romantic events / surprises
/// / calls / missed calls. FCM token is stored under
/// `device_tokens/{uid}` (rules: only that UID may write it).
/// Local notifications show incoming-call / message alerts while the
/// app is in the foreground. Respects Android notification permission
/// and Do Not Disturb — the OS, not the app, has the final say.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: android),
    );
    final token = await _messaging.getToken();
    await _saveToken(token);
    _messaging.onTokenRefresh.listen(_saveToken);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'Only Us 💕';
      final body = message.notification?.body ?? '';
      if (body.isNotEmpty) {
        showLocal(title: title, body: body);
      }
    });
  }

  Future<void> _saveToken(String? token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || token == null) return;
    await _firestore.collection('device_tokens').doc(uid).set(
      <String, dynamic>{
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': 'android',
      },
      SetOptions(merge: true),
    );
  }

  Future<void> showLocal({required String title, required String body}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'only_us_messages',
        'Only Us messages',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
