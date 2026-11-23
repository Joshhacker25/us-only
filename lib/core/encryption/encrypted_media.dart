/// Encrypted media upload for Surprises — Part A wiring.
///
/// Picks a photo / voice / video file, encrypts the raw bytes with
/// the couple key (AES-GCM), uploads only the encrypted bytes to
/// Firebase Storage, and returns the storage path to store as the
/// surprise ciphertext. Plaintext media never leaves the device.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/surprises/data/surprise_service.dart' show SurpriseType;
import 'encryption_service.dart';

class EncryptedMediaUploader {
  EncryptedMediaUploader({
    required this.encryption,
    required this.coupleId,
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _imagePicker = imagePicker ?? ImagePicker();

  final EncryptionService encryption;
  final String coupleId;
  final FirebaseStorage _storage;
  final ImagePicker _imagePicker;

  Future<String?> pickAndUploadEncrypted(SurpriseType type) async {
    File? file;
    if (type == SurpriseType.photo) {
      final picked =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return null;
      file = File(picked.path);
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: type == SurpriseType.voice
            ? FileType.audio
            : FileType.video,
      );
      if (result == null || result.files.single.path == null) return null;
      file = File(result.files.single.path!);
    }
    final bytes = await file.readAsBytes();
    final encrypted = await encryption.encryptBytes(bytes);
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${type.name}.enc';
    final ref = _storage
        .ref()
        .child('couples/$coupleId/surprises/$name');
    await ref.putData(encrypted);
    return ref.fullPath;
  }

  Future<Uint8List?> downloadAndDecrypt(String storagePath) async {
    try {
      final data = await _storage.ref(storagePath).getData();
      if (data == null) return null;
      return encryption.decryptBytes(data);
    } catch (_) {
      return null;
    }
  }
}
