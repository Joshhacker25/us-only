/// Couple shared-key encryption — Part A.
///
/// AES-256-GCM via the maintained `encrypt` package. The key is a
/// 32-byte random key stored in Android Keystore-backed
/// `flutter_secure_storage` (see [KeyStore]). It is generated on first
/// run and must be provisioned to the partner out-of-band during setup
/// (see docs/PROVISIONING.md — export/import the base64 key over a
/// channel you already trust, e.g. in person / QR; never send it in
/// chat, email, or through Firestore).
///
/// HONEST STATUS: this is a real AES-GCM implementation for text and
/// bytes, with a documented key lifecycle, but it has NOT been audited
/// and has NOT been verified end-to-end on two real devices. Do not
/// describe Only Us as "audited E2EE" or "proven E2EE" until the
/// two-device test in docs/RELEASE_CHECKLIST.md has actually passed.
/// No custom cryptography was invented here.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;

import '../../features/nearby/data/nearby_service.dart' show NearbyPayloadCipher;
import 'key_store.dart';

class EncryptionService implements NearbyPayloadCipher {
  EncryptionService({KeyStore? keyStore})
      : _keyStore = keyStore ?? KeyStore();

  final KeyStore _keyStore;
  enc.Key? _key;

  Future<void> ensureKey() async {
    if (_key != null) return;
    final existing = await _keyStore.readCoupleKey();
    if (existing != null && existing.length == 32) {
      _key = enc.Key(existing);
      return;
    }
    final generated = enc.Key.fromSecureRandom(32);
    await _keyStore.writeCoupleKey(generated.bytes);
    _key = generated;
  }

  /// Base64 of the current couple key, for out-of-band provisioning
  /// to the partner. Handle it like a password: never log it, never
  /// send it through the app, never commit it.
  Future<String?> exportKeyBase64() async {
    await ensureKey();
    return base64Encode(_key!.bytes);
  }

  Future<bool> importKeyBase64(String base64Key) async {
    try {
      final bytes = base64Decode(base64Key.trim());
      if (bytes.length != 32) return false;
      await _keyStore.writeCoupleKey(bytes);
      _key = enc.Key(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<enc.Key> _getKey() async {
    await ensureKey();
    return _key!;
  }

  /// Encrypts [plaintext] -> base64(iv + ciphertext + tag).
  Future<String> encryptText(String plaintext) async {
    final key = await _getKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    final combined = Uint8List.fromList(<int>[...iv.bytes, ...encrypted.bytes]);
    return base64Encode(combined);
  }

  Future<String?> decryptText(String ciphertext) async {
    try {
      final key = await _getKey();
      final combined = base64Decode(ciphertext);
      if (combined.length < 17) return null;
      final iv = enc.IV(combined.sublist(0, 16));
      final data = enc.Encrypted(combined.sublist(16));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return encrypter.decrypt(data, iv: iv);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> encryptBytes(Uint8List bytes) async {
    final key = await _getKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);
    return Uint8List.fromList(<int>[...iv.bytes, ...encrypted.bytes]);
  }

  Future<Uint8List?> decryptBytes(Uint8List encryptedBytes) async {
    try {
      final key = await _getKey();
      if (encryptedBytes.length < 17) return null;
      final iv = enc.IV(encryptedBytes.sublist(0, 16));
      final data = enc.Encrypted(encryptedBytes.sublist(16));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return Uint8List.fromList(encrypter.decryptBytes(data, iv: iv));
    } catch (_) {
      return null;
    }
  }

  // -- NearbyPayloadCipher (synchronous contract) -------------------
  // Nearby needs a sync encrypt/decrypt. AES-GCM here is async only
  // because the key lives in secure storage, so the app shell must call
  // [ensureKey] at startup; after that these use the in-memory key.
  // If no key is loaded yet they throw instead of sending plaintext.
  @override
  String encrypt(String plaintext) {
    final key = _key;
    if (key == null) {
      throw StateError('Encryption key not loaded — call ensureKey() first.');
    }
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return base64Encode(
        Uint8List.fromList(<int>[...iv.bytes, ...encrypted.bytes]));
  }

  @override
  String? decrypt(String ciphertext) {
    try {
      final key = _key;
      if (key == null) return null;
      final combined = base64Decode(ciphertext);
      if (combined.length < 17) return null;
      final iv = enc.IV(combined.sublist(0, 16));
      final data = enc.Encrypted(combined.sublist(16));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return encrypter.decrypt(data, iv: iv);
    } catch (_) {
      return null;
    }
  }
}
