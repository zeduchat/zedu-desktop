import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

/// True when [text] has a high or low surrogate without its partner.
bool _hasLoneSurrogate(String text) {
  final units = text.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    final isHigh = unit >= 0xD800 && unit <= 0xDBFF;
    final isLow = unit >= 0xDC00 && unit <= 0xDFFF;
    if (isHigh) {
      final next = i + 1 < units.length ? units[i + 1] : 0;
      if (next < 0xDC00 || next > 0xDFFF) return true;
      i++;
    } else if (isLow) {
      return true;
    }
  }
  return false;
}

void main() {
  group('notificationPreview (Ziki #2439)', () {
    test('leaves text of 80 characters or fewer unchanged', () {
      final text = 'a' * 80;
      expect(notificationPreview(text), text);
      expect(notificationPreview('Hello 👋'), 'Hello 👋');
    });

    test('keeps the first 77 characters and adds an ellipsis', () {
      final text = 'a' * 81;
      expect(notificationPreview(text), '${'a' * 77}...');
    });

    test('does not split an emoji at the cut', () {
      // 76 letters, then an emoji as character 77: substring(0, 77) used to
      // keep only its high surrogate.
      final text = '${'a' * 76}😀${'b' * 10}';
      final preview = notificationPreview(text);

      expect(preview, '${'a' * 76}😀...');
      expect(_hasLoneSurrogate(preview), isFalse);
    });

    test('keeps a family emoji and an accented letter whole at the cut', () {
      const family = '👨‍👩‍👧';
      const accented = 'é'; // e + combining acute accent
      final withFamily = '${'a' * 76}$family${'b' * 10}';
      final withAccent = '${'a' * 76}$accented${'b' * 10}';

      expect(notificationPreview(withFamily), '${'a' * 76}$family...');
      expect(notificationPreview(withAccent), '${'a' * 76}$accented...');
    });

    test('counts emoji as one character each when deciding to cut', () {
      // 80 emoji are 160 UTF-16 units but 80 characters, so nothing is cut.
      final text = '😀' * 80;
      expect(notificationPreview(text), text);
      expect(notificationPreview('😀' * 81), '${'😀' * 77}...');
    });
  });
}
