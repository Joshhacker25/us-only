/// Local cache — Part A.
///
/// Encrypted-at-rest in the sense that only ciphertext is stored here:
/// chat/media payloads are encrypted by [EncryptionService] before
/// they reach this cache, and the key lives in Keystore-backed secure
/// storage. The SQLite file itself is not SQLCipher — see
/// docs/SECURITY_THREAT_MODEL.md. Used for offline queue + message
/// cache so the chat works without connectivity and syncs on reconnect.
library;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'only_us_cache.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
            'CREATE TABLE outbox(id TEXT PRIMARY KEY, conversationId TEXT, clientId TEXT, ciphertext TEXT, kind TEXT, createdAt INTEGER)');
        await db.execute(
            'CREATE TABLE message_cache(id TEXT PRIMARY KEY, conversationId TEXT, clientId TEXT, ciphertext TEXT, kind TEXT, createdAt INTEGER)');
      },
    );
    return _db!;
  }

  Future<void> enqueueOutbox({
    required String id,
    required String conversationId,
    required String clientId,
    required String ciphertext,
    required String kind,
  }) async {
    final database = await db;
    await database.insert(
      'outbox',
      <String, Object?>{
        'id': id,
        'conversationId': conversationId,
        'clientId': clientId,
        'ciphertext': ciphertext,
        'kind': kind,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> pendingOutbox() async {
    final database = await db;
    return database.query('outbox', orderBy: 'createdAt ASC');
  }

  Future<void> removeFromOutbox(String id) async {
    final database = await db;
    await database.delete('outbox', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
