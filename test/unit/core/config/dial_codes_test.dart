import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('DialCode.match', () {
    test('finds the country a number starts with', () {
      expect(DialCode.match('+2348012345678')?.iso, 'NG');
      expect(DialCode.match('+44 20 7946 0958')?.iso, 'GB');
    });

    test('prefers the longest code and the main owner of a shared one', () {
      expect(DialCode.match('+1 242 555 0100')?.iso, 'BS');
      expect(DialCode.match('+1 415 555 0100')?.iso, 'US');
      expect(DialCode.match('+7 495 123 4567')?.iso, 'RU');
    });

    test('returns null for a number without a code', () {
      expect(DialCode.match('08012345678'), isNull);
      expect(DialCode.match(''), isNull);
    });
  });

  group('DialCode.applyTo', () {
    const nigeria = DialCode('Nigeria', 'NG', '+234');

    test('puts the code in front of a local number', () {
      expect(nigeria.applyTo('801 234 5678'), '+234 801 234 5678');
      expect(nigeria.applyTo(''), '+234 ');
    });

    test('replaces an existing code', () {
      expect(nigeria.applyTo('+1 801 234 5678'), '+234 801 234 5678');
      expect(nigeria.applyTo('+448012345678'), '+234 8012345678');
    });
  });

  test('every country has an ISO code and a dial code', () {
    for (final code in kDialCodes) {
      expect(code.iso, matches(RegExp(r'^[A-Z]{2}$')), reason: code.name);
      expect(code.dial, matches(RegExp(r'^\+\d[\d ]*$')), reason: code.name);
    }
    expect(kDialCodes.map((c) => c.iso).toSet(), hasLength(kDialCodes.length));
  });
}
