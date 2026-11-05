import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/user_profile/presentation/components/edit_profile_dialog.dart';

void main() {
  group('normalizeProfileTimezone', () {
    test('keeps a saved IANA id that is in the list', () {
      expect(normalizeProfileTimezone('Africa/Lagos'), 'Africa/Lagos');
    });

    test('maps a label saved by older builds back to its IANA id', () {
      expect(
        normalizeProfileTimezone('(UTC+01:00) West Central Africa'),
        'Africa/Lagos',
      );
    });

    test('defaults to Africa/Lagos instead of UTC-12 when empty', () {
      expect(normalizeProfileTimezone(''), 'Africa/Lagos');
      expect(normalizeProfileTimezone('   '), 'Africa/Lagos');
    });

    test('keeps an unknown IANA id so saving does not overwrite it', () {
      expect(normalizeProfileTimezone('Africa/Accra'), 'Africa/Accra');
    });
  });
}
