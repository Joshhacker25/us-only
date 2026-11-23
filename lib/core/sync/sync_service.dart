/// Offline queue + reconnect sync — Part A.
///
/// Messages created offline go into [LocalDatabase] outbox.
/// On reconnect, [SyncService] drains the queue in order. Dedup is by
/// `clientId` (Firestore rules + ChatRepository both dedup on it), so
/// a retry can never duplicate a message.
library;

import '../database/local_database.dart';

class SyncService {
  SyncService({LocalDatabase? localDb})
      : _localDb = localDb ?? LocalDatabase.instance;

  final LocalDatabase _localDb;

  Future<List<Map<String, Object?>>> pending() =>
      _localDb.pendingOutbox();

  Future<void> markSent(String id) => _localDb.removeFromOutbox(id);

  /// Drains the outbox using [send], oldest first. Returns the number
  /// sent. A failed item stops the drain (it stays queued for retry).
  Future<int> drain(
      Future<bool> Function(Map<String, Object?> item) send) async {
    final items = await pending();
    var sent = 0;
    for (final item in items) {
      final ok = await send(item);
      if (!ok) break;
      await markSent(item['id'] as String);
      sent++;
    }
    return sent;
  }
}
