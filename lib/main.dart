/// Only Us 💕 — entry point (Part A).
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/encryption/encryption_service.dart';
import 'core/notifications/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      <DeviceOrientation>[DeviceOrientation.portraitUp]);

  // Firebase config is a placeholder until provisioning — see
  // lib/firebase_options.dart and docs/PROVISIONING.md. If it fails,
  // the app shows the error instead of silently running unsecured.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    runApp(_FirebaseErrorApp(error: e.toString()));
    return;
  }

  final encryption = EncryptionService();
  try {
    await encryption.ensureKey();
  } catch (_) {
    // Key generation failure must not crash startup; encryption-gated
    // screens fail closed and explain why.
  }

  try {
    await NotificationService().init();
  } catch (_) {
    // Notifications are best-effort until FCM is provisioned.
  }

  runApp(OnlyUsApp(encryption: encryption));
}

class _FirebaseErrorApp extends StatelessWidget {
  const _FirebaseErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF100B1F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Firebase is not configured yet.\n\n'
              'Follow docs/PROVISIONING.md: create the Firebase project, '
              'register com.onlyus.app, add google-services.json, and '
              'replace lib/firebase_options.dart.\n\n$error',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
