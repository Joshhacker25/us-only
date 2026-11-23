/// Heart / hug / kiss send throttling — pure functions, no Flutter imports.
///
/// Limits (agreed product rules for the Love buttons):
/// * Max **1 heart per 10 seconds** (burst guard — stops accidental
///   double-taps and tap-spam from flooding the partner's phone).
/// * Max **20 hearts per rolling hour** (abuse / runaway-loop guard).
///
/// The functions are pure: they take the list of previously sent
/// timestamps and the current time, and return a decision. Callers own
/// persistence of the timestamp list (e.g. in memory + Firestore) — the
/// server-side rate limit in Firestore rules is the real enforcement;
/// this is the client-side UX guard. See `docs/SECURITY_THREAT_MODEL.md`.
library;

/// Minimum gap between two hearts.
const Duration kMinHeartInterval = Duration(seconds: 10);

/// Rolling window for the hourly cap.
const Duration kHeartHourWindow = Duration(hours: 1);

/// Maximum hearts allowed inside [kHeartHourWindow].
const int kMaxHeartsPerHour = 20;

/// True when a heart may be sent at [now], given the timestamps of
/// hearts already sent ([sentAt], any order, any timezone — all are
/// compared as UTC instants).
bool canSendHeart({
  required List<DateTime> sentAt,
  required DateTime now,
}) {
  final nowUtc = now.toUtc();
  final sentUtc = sentAt.map((t) => t.toUtc()).toList();

  // Rule 1: at least 10 seconds since the most recent heart.
  if (sentUtc.isNotEmpty) {
    final latest = sentUtc.reduce((a, b) => a.isAfter(b) ? a : b);
    if (nowUtc.difference(latest) < kMinHeartInterval) return false;
  }

  // Rule 2: fewer than 20 hearts in the last rolling hour.
  // A heart exactly 1 hour old no longer counts (window is (now - 1h, now]).
  final windowStart = nowUtc.subtract(kHeartHourWindow);
  final inWindow = sentUtc.where((t) => t.isAfter(windowStart)).length;
  if (inWindow >= kMaxHeartsPerHour) return false;

  return true;
}

/// The earliest instant at which the next heart may be sent, given the
/// timestamps of hearts already sent. Returns [now] (as UTC) when a
/// heart may be sent immediately.
DateTime nextHeartAllowedAt({
  required List<DateTime> sentAt,
  required DateTime now,
}) {
  if (canSendHeart(sentAt: sentAt, now: now)) return now.toUtc();

  final nowUtc = now.toUtc();
  final sentUtc = sentAt.map((t) => t.toUtc()).toList()..sort();

  // Blocked by the 10-second rule?
  if (sentUtc.isNotEmpty) {
    final latest = sentUtc.last;
    final earliestAfterGap = latest.add(kMinHeartInterval);
    if (earliestAfterGap.isAfter(nowUtc)) {
      // The hourly cap could push this even later; take the max below.
      final hourBlock = _hourCapLiftTime(sentUtc, nowUtc);
      return earliestAfterGap.isAfter(hourBlock)
          ? earliestAfterGap
          : hourBlock;
    }
  }

  return _hourCapLiftTime(sentUtc, nowUtc);
}

/// Earliest instant the hourly cap stops blocking, or [nowUtc] if it
/// does not block.
DateTime _hourCapLiftTime(List<DateTime> sortedSentUtc, DateTime nowUtc) {
  final windowStart = nowUtc.subtract(kHeartHourWindow);
  final inWindow =
      sortedSentUtc.where((t) => t.isAfter(windowStart)).toList();
  if (inWindow.length < kMaxHeartsPerHour) return nowUtc;
  // The cap lifts when the oldest heart in the window ages out (+1s so
  // the boundary is unambiguous).
  return inWindow.first.add(kHeartHourWindow).add(const Duration(seconds: 1));
}
