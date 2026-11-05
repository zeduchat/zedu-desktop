import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/utils/initials.dart';

void main() {
  group('avatarInitial', () {
    test('upper-cases the first letter', () {
      expect(avatarInitial('ada'), 'A');
      expect(avatarInitial('Émile'), 'É');
    });

    test('keeps an emoji whole instead of half a surrogate pair', () {
      expect(avatarInitial('😀 Ada'), '😀');
      expect(avatarInitial('🚀launch'), '🚀');
    });

    test('keeps a flag, a joined emoji and a skin tone whole', () {
      expect(avatarInitial('🇳🇬 Lagos'), '🇳🇬');
      expect(avatarInitial('👩‍💻 dev'), '👩‍💻');
      expect(avatarInitial('👍🏽 yes'), '👍🏽');
    });

    test('keeps a letter with a combining accent whole', () {
      expect(avatarInitial('émile'), 'É');
    });

    test('ignores leading spaces', () {
      expect(avatarInitial('  bola'), 'B');
    });

    test('falls back when there is no name', () {
      expect(avatarInitial(''), '?');
      expect(avatarInitial('   '), '?');
      expect(avatarInitial(null), '?');
      expect(avatarInitial('', fallback: '#'), '#');
    });
  });

  group('avatarInitial edge cases', () {
    test('returns the upper-cased first letter of a name', () {
      expect(avatarInitial('John'), 'J');
      expect(avatarInitial('ada okafor'), 'A');
    });

    test('ignores leading and trailing whitespace', () {
      expect(avatarInitial(' John'), 'J');
      expect(avatarInitial('\t\n ada  '), 'A');
    });

    test('falls back to ? for null, empty or whitespace-only names', () {
      expect(avatarInitial(null), '?');
      expect(avatarInitial(''), '?');
      expect(avatarInitial('   '), '?');
      expect(avatarInitial('\t\n'), '?');
    });

    test('uses the given fallback when the name is blank', () {
      expect(avatarInitial('', fallback: 'Z'), 'Z');
      expect(avatarInitial(' ', fallback: avatarInitial('mo@zedu.chat')), 'M');
      expect(avatarInitial('Ada', fallback: 'Z'), 'A');
    });

    test('keeps an emoji or accented letter whole', () {
      expect(avatarInitial('😀 Smile'), '😀');
      expect(avatarInitial('👨‍👩‍👧 Family'), '👨‍👩‍👧');
      expect(avatarInitial('émile'), 'É');
    });

    test('handles very long names', () {
      expect(avatarInitial('x' * 10000), 'X');
    });
  });
}
