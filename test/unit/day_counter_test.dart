import 'package:flutter_test/flutter_test.dart';

// NOTE: relative import (not package:only_us/...) so this test runs
// whatever package name Part A gives the app in pubspec.yaml.
import '../../lib/shared/utils/day_counter.dart';

void main() {
  group('relationshipDayNumber', () {
    test('same day as start date is day 1', () {
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2026, 1, 1),
          now: DateTime.utc(2026, 1, 1),
        ),
        1,
      );
    });

    test('same day counts as day 1 regardless of time of day', () {
      // Started late at night, checked early the same calendar day.
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2026, 1, 1, 23, 59),
          now: DateTime.utc(2026, 1, 1, 0, 1),
        ),
        1,
      );
      // Started 23:59, checked 00:01 the next calendar day -> day 2.
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2026, 1, 1, 23, 59),
          now: DateTime.utc(2026, 1, 2, 0, 1),
        ),
        2,
      );
    });

    test('next calendar day is day 2', () {
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2026, 1, 1),
          now: DateTime.utc(2026, 1, 2),
        ),
        2,
      );
    });

    test('counts across month and year boundaries', () {
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2025, 12, 31),
          now: DateTime.utc(2026, 1, 1),
        ),
        2,
      );
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2026, 1, 1),
          now: DateTime.utc(2027, 1, 1),
        ),
        366, // 2026 is not a leap year: 365 days + 1.
      );
    });

    test('leap year: Feb 29 exists in 2024', () {
      // 2024-02-28 = day 1, 2024-02-29 = day 2, 2024-03-01 = day 3.
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2024, 2, 28),
          now: DateTime.utc(2024, 3, 1),
        ),
        3,
      );
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2024, 2, 29),
          now: DateTime.utc(2024, 3, 1),
        ),
        2,
      );
    });

    test('non-leap year: no Feb 29 in 2023', () {
      // 2023-02-28 = day 1, 2023-03-01 = day 2.
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2023, 2, 28),
          now: DateTime.utc(2023, 3, 1),
        ),
        2,
      );
    });

    test('leap day anniversary: 2024-02-29 to 2025-02-28 is day 366', () {
      // 365 days elapsed, +1 because the start day is day 1.
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2024, 2, 29),
          now: DateTime.utc(2025, 2, 28),
        ),
        366,
      );
    });

    test('now before start date returns 0 (not started)', () {
      expect(
        relationshipDayNumber(
          startDate: DateTime.utc(2026, 6, 1),
          now: DateTime.utc(2026, 5, 31),
        ),
        0,
      );
    });

    test('timezone-safe: same instant in different offsets, same result', () {
      // Start: 2026-01-01 00:30 in +05:30 == 2025-12-31 19:00 UTC.
      // Now:  2026-01-01 12:00 in -05:00 == 2026-01-01 17:00 UTC.
      // In UTC both fall on different calendar days -> day 2.
      final start = DateTime.parse('2026-01-01T00:30:00+05:30');
      final now = DateTime.parse('2026-01-01T12:00:00-05:00');
      expect(
        relationshipDayNumber(startDate: start, now: now),
        2,
      );
    });
  });

  group('daysSinceStart', () {
    test('0 on the start day, 1 the next day', () {
      expect(
        daysSinceStart(
          startDate: DateTime.utc(2026, 1, 1),
          now: DateTime.utc(2026, 1, 1),
        ),
        0,
      );
      expect(
        daysSinceStart(
          startDate: DateTime.utc(2026, 1, 1),
          now: DateTime.utc(2026, 1, 2),
        ),
        1,
      );
    });

    test('0 when now is before the start date', () {
      expect(
        daysSinceStart(
          startDate: DateTime.utc(2026, 6, 1),
          now: DateTime.utc(2026, 5, 1),
        ),
        0,
      );
    });
  });

  group('isAnniversary', () {
    test('true on the same month/day one year later', () {
      expect(
        isAnniversary(
          startDate: DateTime.utc(2025, 3, 14),
          now: DateTime.utc(2026, 3, 14),
        ),
        isTrue,
      );
    });

    test('false on other days and in the first year', () {
      expect(
        isAnniversary(
          startDate: DateTime.utc(2025, 3, 14),
          now: DateTime.utc(2026, 3, 15),
        ),
        isFalse,
      );
      expect(
        isAnniversary(
          startDate: DateTime.utc(2025, 3, 14),
          now: DateTime.utc(2025, 3, 14),
        ),
        isFalse,
      );
    });
  });
}
