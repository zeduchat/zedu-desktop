import 'package:zedu/features/dms/presentation/components/composer/composer.dart';

import '../../../../../../helpers/helpers.dart';

const _base = TextStyle(fontSize: 14);

/// Leaf runs of [span] as (text, style) pairs, in order.
List<(String, TextStyle)> _runs(InlineSpan span) {
  final runs = <(String, TextStyle)>[];
  void walk(InlineSpan s, TextStyle inherited) {
    if (s is! TextSpan) return;
    final style = inherited.merge(s.style);
    if (s.text != null && s.text!.isNotEmpty) runs.add((s.text!, style));
    for (final child in s.children ?? const <InlineSpan>[]) {
      walk(child, style);
    }
  }

  walk(span, const TextStyle());
  return runs;
}

bool _hidden((String, TextStyle) run) => run.$2.color == Colors.transparent;

List<(String, TextStyle)> _visible(InlineSpan span) =>
    _runs(span).where((r) => !_hidden(r)).toList();

String _visibleText(InlineSpan span) => _visible(span).map((r) => r.$1).join();

bool _isBold(TextStyle s) => s.fontWeight == FontWeight.bold;
bool _isItalic(TextStyle s) => s.fontStyle == FontStyle.italic;

void main() {
  group('buildInlineMarkdownSpan', () {
    test('bold then italic (***word***) renders bold and italic', () {
      // Toolbar: Bold wraps `test` in **, then Italic wraps that in *.
      final span = buildInlineMarkdownSpan('***test***', _base);

      expect(_visibleText(span), 'test');
      final run = _visible(span).single;
      expect(_isBold(run.$2), isTrue);
      expect(_isItalic(run.$2), isTrue);
    });

    test('italic then bold gives the same text and both styles', () {
      // Toolbar: Italic wraps `test` in *, then Bold wraps that in **.
      const text =
          '**'
          '*test*'
          '**';
      final span = buildInlineMarkdownSpan(text, _base);

      expect(_visibleText(span), 'test');
      final run = _visible(span).single;
      expect(_isBold(run.$2), isTrue);
      expect(_isItalic(run.$2), isTrue);
    });

    test('keepMarkers keeps the raw text but hides every marker', () {
      const text = 'say ***hi*** now';
      final span = buildInlineMarkdownSpan(text, _base, keepMarkers: true);

      // Cursor offsets in the composer index into the raw text.
      expect(span.toPlainText(), text);
      expect(_visibleText(span), 'say hi now');
      expect(
        _runs(span).where(_hidden).every((r) => r.$1.contains('*')),
        isTrue,
      );
    });

    test('plain bold, italic, strike and code still work', () {
      final span = buildInlineMarkdownSpan('**b** *i* ~~s~~ `c`', _base);
      final runs = _visible(span);

      expect(_visibleText(span), 'b i s c');
      expect(_isBold(runs.firstWhere((r) => r.$1 == 'b').$2), isTrue);
      expect(_isItalic(runs.firstWhere((r) => r.$1 == 'i').$2), isTrue);
      expect(
        runs.firstWhere((r) => r.$1 == 's').$2.decoration,
        TextDecoration.lineThrough,
      );
      expect(runs.firstWhere((r) => r.$1 == 'c').$2.fontFamily, 'monospace');
    });

    test('italic inside bold and bold inside italic both nest', () {
      final a = _visible(buildInlineMarkdownSpan('**a *b* c**', _base));
      expect(a.map((r) => r.$1).join(), 'a b c');
      expect(a.every((r) => _isBold(r.$2)), isTrue);
      expect(_isItalic(a.firstWhere((r) => r.$1 == 'b').$2), isTrue);
      expect(_isItalic(a.firstWhere((r) => r.$1 == 'a ').$2), isFalse);

      final b = _visible(buildInlineMarkdownSpan('*a **b** c*', _base));
      expect(b.map((r) => r.$1).join(), 'a b c');
      expect(b.every((r) => _isItalic(r.$2)), isTrue);
      expect(_isBold(b.firstWhere((r) => r.$1 == 'b').$2), isTrue);
    });

    test('strike around bold nests; code stays literal', () {
      final strike = _visible(buildInlineMarkdownSpan('~~**x**~~', _base));
      expect(strike.single.$1, 'x');
      expect(_isBold(strike.single.$2), isTrue);
      expect(strike.single.$2.decoration, TextDecoration.lineThrough);

      final code = _visible(buildInlineMarkdownSpan('`**x**`', _base));
      expect(code.single.$1, '**x**');
      expect(_isBold(code.single.$2), isFalse);
    });

    test('bold-italic works next to other text, emoji and newlines', () {
      const text = '👋 ***héllo wörld 🎉***\nnext ***line***';
      final span = buildInlineMarkdownSpan(text, _base, keepMarkers: true);

      expect(span.toPlainText(), text);
      expect(_visibleText(span), '👋 héllo wörld 🎉\nnext line');
      for (final run in _visible(span)) {
        final styled = run.$1 == 'héllo wörld 🎉' || run.$1 == 'line';
        expect(_isBold(run.$2) && _isItalic(run.$2), styled, reason: run.$1);
      }
    });

    test('empty markers from a collapsed toolbar click show nothing', () {
      for (final text in ['**', '****', '******']) {
        final span = buildInlineMarkdownSpan(text, _base, keepMarkers: true);
        expect(span.toPlainText(), text);
        expect(_visibleText(span), '', reason: text);
      }
    });

    test('unmatched markers stay as plain text', () {
      for (final text in ['a * b', '***x', '2*3', '*open']) {
        final span = buildInlineMarkdownSpan(text, _base);
        expect(_visibleText(span), text, reason: text);
      }
    });

    test('empty text gives an empty span', () {
      expect(buildInlineMarkdownSpan('', _base).toPlainText(), '');
    });

    test('long text with many markers stays fast', () {
      final text = List.filled(2000, '***word*** *a* **b** ').join();
      final watch = Stopwatch()..start();
      final span = buildInlineMarkdownSpan(text, _base, keepMarkers: true);
      watch.stop();

      expect(span.toPlainText(), text);
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('RichTextController', () {
    testWidgets('composer hides the markers of bold and italic text', (
      tester,
    ) async {
      final controller = RichTextController(text: '***test***');
      addTearDown(controller.dispose);
      late TextSpan span;
      await tester.pumpWidget(
        buildTestMaterialApp(
          Builder(
            builder: (context) {
              span = controller.buildTextSpan(
                context: context,
                style: _base,
                withComposing: false,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(span.toPlainText(), '***test***');
      final run = _visible(span).single;
      expect(run.$1, 'test');
      expect(_isBold(run.$2) && _isItalic(run.$2), isTrue);
    });
  });
}
