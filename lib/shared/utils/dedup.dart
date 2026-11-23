/// Message deduplication by client ID — pure function, no Flutter imports.
///
/// Why this exists: a message can arrive twice — once as the optimistic
/// local echo (written with a `clientId` when the user hits send) and once
/// from the Firestore snapshot (same `clientId`, server-assigned id).
/// Without dedup the chat would show the same message twice.
///
/// Rules:
/// * The **first** occurrence of a `clientId` wins; later duplicates are
///   dropped. Original list order is preserved.
/// * Items with an **empty** `clientId` are never deduplicated — an empty
///   id carries no identity, so collapsing two of them would delete a
///   real message. (Callers should always assign a `clientId` at send
///   time, e.g. a UUID.)
library;

/// Returns a new list with later items whose `clientId` was already seen
/// removed. [clientIdOf] extracts the client id from an item.
List<T> dedupeByClientId<T>(
  List<T> items,
  String Function(T item) clientIdOf,
) {
  final seen = <String>{};
  final result = <T>[];
  for (final item in items) {
    final clientId = clientIdOf(item);
    if (clientId.isEmpty) {
      // No identity -> cannot be a duplicate. Keep it.
      result.add(item);
      continue;
    }
    if (seen.add(clientId)) {
      result.add(item);
    }
    // else: duplicate clientId, drop it.
  }
  return result;
}

/// Convenience for the common case where a message is represented as a
/// `Map` with a `'clientId'` key.
List<Map<String, dynamic>> dedupeMessageMaps(
  List<Map<String, dynamic>> messages,
) {
  return dedupeByClientId<Map<String, dynamic>>(
    messages,
    (m) => (m['clientId'] as String?) ?? '',
  );
}
