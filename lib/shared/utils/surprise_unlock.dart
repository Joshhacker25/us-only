/// Surprise unlock logic — pure functions, no Flutter imports.
///
/// A "surprise" (a scheduled love note / gift) is locked until its
/// `unlockAt` instant and unlocked from that instant onwards.
///
/// Rules:
/// * Locked when `now < unlockAt`, unlocked when `now >= unlockAt`
///   (unlocked *exactly* at the unlock instant).
/// * Comparison is done on the UTC instant (`millisecondsSinceEpoch`
///   after `toUtc()`), so the result is identical on both phones even
///   if they are in different timezones or one changes timezone.
/// * The server (Firestore rules / Cloud Function) is the authority for
///   the real unlock; this client-side check only decides what to show.
///   See `docs/SECURITY_THREAT_MODEL.md`.
library;

/// True when the surprise may be shown at [now].
bool isSurpriseUnlocked({
  required DateTime unlockAt,
  required DateTime now,
}) {
  return !now.toUtc().isBefore(unlockAt.toUtc());
}

/// How long until the surprise unlocks. Returns [Duration.zero] when
/// already unlocked (never negative).
Duration timeUntilUnlock({
  required DateTime unlockAt,
  required DateTime now,
}) {
  final remaining = unlockAt.toUtc().difference(now.toUtc());
  return remaining.isNegative ? Duration.zero : remaining;
}
