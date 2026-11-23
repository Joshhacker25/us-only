/// Relationship day counter — pure functions, no Flutter imports.
///
/// Rules (see `test/unit/day_counter_test.dart`):
/// * The start date itself is **day 1** (same-day = day 1).
/// * Only whole calendar days count; the time of day is ignored.
/// * All comparisons are done in UTC so the result is the same on both
///   phones regardless of local timezone.
/// * Leap years are handled by calendar arithmetic: 2024-02-28 -> 2024-03-01
///   is 2 days apart (because 2024-02-29 exists), while 2023-02-28 ->
///   2023-03-01 is 1 day apart.
///
/// If [now] is before the start date, the result is 0 (the relationship
/// has not started yet) — callers should treat 0 as "not started".
library;

/// Strips a [DateTime] to its UTC calendar date (midnight UTC).
DateTime _utcDate(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

/// The relationship day number on [now] for a relationship that started
/// on [startDate].
///
/// * Same calendar day as [startDate] -> 1
/// * Next calendar day -> 2
/// * [now] before [startDate] -> 0
int relationshipDayNumber({
  required DateTime startDate,
  required DateTime now,
}) {
  final start = _utcDate(startDate);
  final current = _utcDate(now);
  final diffDays = current.difference(start).inDays;
  if (diffDays < 0) return 0;
  return diffDays + 1;
}

/// Whole calendar days elapsed since [startDate] (0 on the start day).
/// This is `relationshipDayNumber(...) - 1`, clamped at 0.
int daysSinceStart({
  required DateTime startDate,
  required DateTime now,
}) {
  final day = relationshipDayNumber(startDate: startDate, now: now);
  return day == 0 ? 0 : day - 1;
}

/// True when [now] falls on the yearly anniversary of [startDate]
/// (same month and day, and at least one year later).
bool isAnniversary({
  required DateTime startDate,
  required DateTime now,
}) {
  final start = _utcDate(startDate);
  final current = _utcDate(now);
  if (current.isBefore(start)) return false;
  if (current.year == start.year) return false;
  return current.month == start.month && current.day == start.day;
}
