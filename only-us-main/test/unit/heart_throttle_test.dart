import 'package:flutter_test/flutter_test.dart';

// NOTE: relative import (not package:only_us/...) so this test runs
// whatever package name Part A gives the app in pubspec.yaml.
import '../../lib/shared/utils/heart_throttle.dart';

void main() {
  group('canSendHeart — 10 second rule', () {
    test('first heart ever is allowed', () {
      expect(
        canSendHeart(sentAt: [], now: DateTime.utc(2026, 1, 1, 12, 0)),
        isTrue,
      );
    });

    test('second heart within 10 seconds is denied', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      expect(
        canSendHeart(
          sentAt: [now.subtract(const Duration(seconds: 9))],
          now: now,
        ),
        isFalse,
      );
      expect(
        canSendHeart(
          sentAt: [now.subtract(const Duration(seconds: 1))],
          now: now,
        ),
        isFalse,
      );
      expect(
        canSendHeart(sentAt: [now], now: now),
        isFalse,
      );
    });

    test('heart exactly 10 seconds after the last one is allowed', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 10);
      expect(
        canSendHeart(
          sentAt: [DateTime.utc(2026, 1, 1, 12, 0, 0)],
          now: now,
        ),
        isTrue,
      );
    });

    test('heart 11 seconds after the last one is allowed', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 11);
      expect(
        canSendHeart(
          sentAt: [DateTime.utc(2026, 1, 1, 12, 0, 0)],
          now: now,
        ),
        isTrue,
      );
    });

    test('only the most recent heart matters for the 10s rule', () {
      final now = DateTime.utc(2026, 1, 1, 12, 1, 0);
      expect(
        canSendHeart(
          sentAt: [
            DateTime.utc(2026, 1, 1, 11, 0, 0), // old
            DateTime.utc(2026, 1, 1, 12, 0, 50), // 10s ago exactly
          ],
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('canSendHeart — 20 per hour rule', () {
    List<DateTime> twentyInLastHour(DateTime now) {
      // 20 hearts, one every 3 minutes, all inside the last hour,
      // the most recent one 11 seconds ago (so the 10s rule passes).
      return List.generate(
        20,
        (i) => now.subtract(Duration(minutes: 3 * (19 - i), seconds: 11)),
      );
    }

    test('20 hearts in the last hour blocks the 21st', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      expect(
        canSendHeart(sentAt: twentyInLastHour(now), now: now),
        isFalse,
      );
    });

    test('19 hearts in the last hour allows one more', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final sent = twentyInLastHour(now).sublist(1); // 19 hearts
      expect(canSendHeart(sentAt: sent, now: now), isTrue);
    });

    test('hearts older than one hour do not count toward the cap', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final old = List.generate(
        20,
        (i) => now.subtract(Duration(hours: 2, minutes: i)),
      );
      expect(canSendHeart(sentAt: old, now: now), isTrue);
    });

    test('a heart exactly one hour old no longer counts', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      // 19 recent + 1 exactly 60 minutes old = 19 in window.
      final sent = [
        now.subtract(const Duration(hours: 1)),
        ...List.generate(
          19,
          (i) => now.subtract(Duration(minutes: 3 * (18 - i), seconds: 11)),
        ),
      ];
      expect(sent, hasLength(20));
      expect(canSendHeart(sentAt: sent, now: now), isTrue);
    });

    test('both rules apply together: 20/hour blocks even after 10s passed', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      // Last heart 30s ago (10s rule passes) but 20 in the last hour.
      final sent = List.generate(
        20,
        (i) => now.subtract(Duration(minutes: 3 * (19 - i), seconds: 30)),
      );
      expect(canSendHeart(sentAt: sent, now: now), isFalse);
    });

    test('unsorted input still works', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final sent = twentyInLastHour(now).reversed.toList();
      expect(canSendHeart(sentAt: sent, now: now), isFalse);
    });
  });

  group('nextHeartAllowedAt', () {
    test('returns now when a heart may be sent immediately', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      expect(
        nextHeartAllowedAt(sentAt: [], now: now),
        now,
      );
    });

    test('returns last heart + 10s when blocked by the interval rule', () {
      final last = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final now = last.add(const Duration(seconds: 4));
      expect(
        nextHeartAllowedAt(sentAt: [last], now: now),
        last.add(const Duration(seconds: 10)),
      );
    });
  });
}
