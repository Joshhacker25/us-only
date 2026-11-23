import 'package:flutter_test/flutter_test.dart';

// NOTE: relative import (not package:only_us/...) so this test runs
// whatever package name Part A gives the app in pubspec.yaml.
import '../../lib/shared/utils/surprise_unlock.dart';

void main() {
  group('isSurpriseUnlocked', () {
    test('locked when now is before unlockAt', () {
      expect(
        isSurpriseUnlocked(
          unlockAt: DateTime.utc(2026, 12, 25, 0, 0),
          now: DateTime.utc(2026, 12, 24, 23, 59, 59),
        ),
        isFalse,
      );
    });

    test('unlocked exactly at unlockAt', () {
      expect(
        isSurpriseUnlocked(
          unlockAt: DateTime.utc(2026, 12, 25, 0, 0),
          now: DateTime.utc(2026, 12, 25, 0, 0),
        ),
        isTrue,
      );
    });

    test('unlocked after unlockAt', () {
      expect(
        isSurpriseUnlocked(
          unlockAt: DateTime.utc(2026, 12, 25, 0, 0),
          now: DateTime.utc(2026, 12, 26, 12, 0),
        ),
        isTrue,
      );
    });

    test('locked one second before, unlocked one second after', () {
      final unlockAt = DateTime.utc(2026, 2, 14, 0, 0, 0);
      expect(
        isSurpriseUnlocked(
          unlockAt: unlockAt,
          now: unlockAt.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(
        isSurpriseUnlocked(
          unlockAt: unlockAt,
          now: unlockAt.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('timezone-safe: same instant in different offsets agrees', () {
      // unlockAt written as UTC midnight; "now" written in +05:30.
      // 2026-12-25T05:30:00+05:30 == 2026-12-25T00:00:00Z exactly.
      final unlockAt = DateTime.utc(2026, 12, 25, 0, 0);
      final nowAtUnlock = DateTime.parse('2026-12-25T05:30:00+05:30');
      final nowBefore = DateTime.parse('2026-12-25T05:29:59+05:30');
      expect(
        isSurpriseUnlocked(unlockAt: unlockAt, now: nowAtUnlock),
        isTrue,
      );
      expect(
        isSurpriseUnlocked(unlockAt: unlockAt, now: nowBefore),
        isFalse,
      );
    });

    test('timezone-safe: a UTC unlock is not shifted by local time', () {
      // A phone in UTC-8 seeing "midnight local" must not unlock early:
      // 2026-12-25T00:00:00-08:00 is 08:00 UTC, after the unlock.
      final unlockAt = DateTime.utc(2026, 12, 25, 0, 0);
      final nowLocalMidnight = DateTime.parse('2026-12-25T00:00:00-08:00');
      expect(
        isSurpriseUnlocked(unlockAt: unlockAt, now: nowLocalMidnight),
        isTrue,
      );
      // And 2026-12-24T23:00:00-08:00 is 2026-12-25T07:00 UTC — after.
      // While 2026-12-24T15:00:00-08:00 is 2026-12-24T23:00 UTC — before.
      final nowStillLocked = DateTime.parse('2026-12-24T15:00:00-08:00');
      expect(
        isSurpriseUnlocked(unlockAt: unlockAt, now: nowStillLocked),
        isFalse,
      );
    });
  });

  group('timeUntilUnlock', () {
    test('returns the remaining duration while locked', () {
      expect(
        timeUntilUnlock(
          unlockAt: DateTime.utc(2026, 12, 25, 0, 0),
          now: DateTime.utc(2026, 12, 24, 0, 0),
        ),
        const Duration(days: 1),
      );
    });

    test('returns zero at and after unlock, never negative', () {
      final unlockAt = DateTime.utc(2026, 12, 25, 0, 0);
      expect(
        timeUntilUnlock(unlockAt: unlockAt, now: unlockAt),
        Duration.zero,
      );
      expect(
        timeUntilUnlock(
          unlockAt: unlockAt,
          now: DateTime.utc(2027, 1, 1),
        ),
        Duration.zero,
      );
    });
  });
}
