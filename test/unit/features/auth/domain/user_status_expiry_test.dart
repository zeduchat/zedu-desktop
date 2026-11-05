import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('UserStatus expiry', () {
    test('a status before its Clear after time is shown', () {
      final status = UserStatus(
        text: 'In a meeting',
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );
      expect(status.isExpired, isFalse);
      expect(status.hasCustomStatus, isTrue);
    });

    test('a status past its Clear after time is not shown', () {
      final status = UserStatus(
        emoji: '📅',
        text: 'In a meeting',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(status.isExpired, isTrue);
      expect(status.hasCustomStatus, isFalse);
    });

    test('a status that never expires is shown', () {
      const status = UserStatus(emoji: '🌴', text: 'Vacationing');
      expect(status.isExpired, isFalse);
      expect(status.hasCustomStatus, isTrue);
    });

    test('no emoji and no text is no status', () {
      expect(const UserStatus().hasCustomStatus, isFalse);
      expect(const UserStatus(text: '').hasCustomStatus, isFalse);
    });
  });
}
