import 'package:flutter_test/flutter_test.dart';

// NOTE: relative import (not package:only_us/...) so this test runs
// whatever package name Part A gives the app in pubspec.yaml.
import '../../lib/shared/utils/allowlist.dart';

void main() {
  group('isAllowedUid', () {
    const partnerA = 'uid-partner-A-abc123';
    const partnerB = 'uid-partner-B-xyz789';
    const allowed = [partnerA, partnerB];

    test('partner A is allowed', () {
      expect(isAllowedUid(partnerA, allowed), isTrue);
    });

    test('partner B is allowed', () {
      expect(isAllowedUid(partnerB, allowed), isTrue);
    });

    test('a third UID is denied', () {
      expect(isAllowedUid('uid-someone-else-000', allowed), isFalse);
    });

    test('a UID that merely contains a partner UID is denied', () {
      expect(isAllowedUid('${partnerA}extra', allowed), isFalse);
      expect(isAllowedUid('x$partnerA', allowed), isFalse);
    });

    test('empty UID is denied', () {
      expect(isAllowedUid('', allowed), isFalse);
    });

    test('null UID is denied', () {
      expect(isAllowedUid(null, allowed), isFalse);
    });

    test('empty allowlist allows nobody', () {
      expect(isAllowedUid(partnerA, []), isFalse);
    });

    test('comparison is case-sensitive (Firebase UIDs are case-sensitive)', () {
      expect(isAllowedUid(partnerA.toUpperCase(), allowed), isFalse);
    });
  });

  group('placeholder UIDs', () {
    test('the two placeholder UIDs are allowed by the placeholder list', () {
      expect(
        isAllowedUid(
          kPartnerAUidPlaceholder,
          kPlaceholderAllowedUids,
        ),
        isTrue,
      );
      expect(
        isAllowedUid(
          kPartnerBUidPlaceholder,
          kPlaceholderAllowedUids,
        ),
        isTrue,
      );
      expect(kPlaceholderAllowedUids, hasLength(2));
    });

    test('a third UID is denied against the placeholder list', () {
      expect(
        isAllowedUid('any-real-firebase-uid', kPlaceholderAllowedUids),
        isFalse,
      );
    });

    test('isPlaceholderAllowedUid helper agrees', () {
      expect(isPlaceholderAllowedUid(kPartnerAUidPlaceholder), isTrue);
      expect(isPlaceholderAllowedUid(kPartnerBUidPlaceholder), isTrue);
      expect(isPlaceholderAllowedUid('third-uid'), isFalse);
      expect(isPlaceholderAllowedUid(null), isFalse);
    });
  });

  group('isPartnerUid', () {
    const partnerA = 'uid-A';
    const partnerB = 'uid-B';
    const allowed = [partnerA, partnerB];

    test('each partner is the other partner', () {
      expect(isPartnerUid(partnerB, partnerA, allowed), isTrue);
      expect(isPartnerUid(partnerA, partnerB, allowed), isTrue);
    });

    test('your own UID is not your partner', () {
      expect(isPartnerUid(partnerA, partnerA, allowed), isFalse);
    });

    test('a third UID is not a partner', () {
      expect(isPartnerUid('uid-C', partnerA, allowed), isFalse);
    });

    test('unknown self UID means no partner match', () {
      expect(isPartnerUid(partnerB, 'uid-C', allowed), isFalse);
    });

    test('a list that is not exactly two UIDs has no partner', () {
      expect(isPartnerUid(partnerB, partnerA, [partnerA]), isFalse);
      expect(
        isPartnerUid(partnerB, partnerA, [partnerA, partnerB, 'uid-C']),
        isFalse,
      );
    });
  });
}
