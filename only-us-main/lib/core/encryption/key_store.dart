/// Android Keystore-backed secret storage (via flutter_secure_storage).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyStore {
  KeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const String _coupleKeyName = 'only_us_couple_key_b64';

  final FlutterSecureStorage _storage;

  Future<Uint8List?> readCoupleKey() async {
    final raw = await _storage.read(key: _coupleKeyName);
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCoupleKey(Uint8List bytes) async {
    await _storage.write(key: _coupleKeyName, value: base64Encode(bytes));
  }

  Future<void> deleteCoupleKey() async {
    await _storage.delete(key: _coupleKeyName);
  }
}
