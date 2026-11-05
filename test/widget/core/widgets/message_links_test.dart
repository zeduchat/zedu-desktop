import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

void main() {
  late List<Uri> opened;
  late Future<bool> Function(Uri) original;

  setUp(() {
    opened = [];
    original = messageLinkLauncher;
    messageLinkLauncher = (uri) async {
      opened.add(uri);
      return true;
    };
  });

  tearDown(() => messageLinkLauncher = original);

  group('messageLinkUri', () {
    for (final url in [
      'https://example.com/a?b=1',
      'http://example.com',
      'HTTPS://EXAMPLE.COM',
      'www.example.com',
    ]) {
      test('allows $url', () => expect(messageLinkUri(url), isNotNull));
    }

    for (final url in [
      'file:///etc/hosts',
      'smb://server/share',
      'javascript:alert(1)',
      'ms-msdt:/id',
      'search-ms:query=a',
      'mailto:a@example.com',
      'https://',
    ]) {
      test('refuses $url', () => expect(messageLinkUri(url), isNull));
    }
  });

  group('openMessageLink', () {
    test('does not launch a refused scheme', () async {
      expect(await openMessageLink('file:///etc/hosts'), isFalse);
      expect(opened, isEmpty);
    });

    test('opens www links over https', () async {
      expect(await openMessageLink('www.example.com'), isTrue);
      expect(opened, [Uri.parse('https://www.example.com')]);
    });

    test('reports a launch failure instead of throwing', () async {
      messageLinkLauncher = (_) async => throw Exception('no browser');
      expect(await openMessageLink('https://example.com'), isFalse);
    });
  });

  group('MessageLinks.span', () {
    const style = TextStyle(fontSize: 14);

    List<String> linkTexts(TextSpan span) {
      final found = <String>[];
      span.visitChildren((child) {
        if (child is TextSpan && child.recognizer != null) {
          found.add(child.text!);
        }
        return true;
      });
      return found;
    }

    late MessageLinks links;

    setUp(() => links = MessageLinks());

    final cases = <String, List<String>>{
      'no links here': [],
      'see https://example.com now': ['https://example.com'],
      'see https://example.com.': ['https://example.com'],
      'see https://example.com, then': ['https://example.com'],
      '(see https://example.com)': ['https://example.com'],
      'https://en.wikipedia.org/wiki/A_(b)': [
        'https://en.wikipedia.org/wiki/A_(b)',
      ],
      'a https://a.com and www.b.com': ['https://a.com', 'www.b.com'],
      'mail me@www.example.com': [],
      'file:///etc/hosts': [],
    };
    cases.forEach((text, expected) {
      test('finds $expected in "$text"', () {
        expect(linkTexts(links.span(text, style)), expected);
      });
    });

    test('keeps the whole message text', () {
      const text = 'a https://a.com. b www.b.com) c';
      expect(links.span(text, style).toPlainText(), text);
    });

    test('underlines a link and keeps its own decoration', () {
      final span = links.span(
        'https://a.com',
        style.copyWith(decoration: TextDecoration.lineThrough),
      );
      final link = span.children!.single as TextSpan;
      expect(
        link.style!.decoration!.contains(TextDecoration.underline),
        isTrue,
      );
      expect(
        link.style!.decoration!.contains(TextDecoration.lineThrough),
        isTrue,
      );
    });

    test('reuses one recognizer for a repeated URL', () {
      final first = links.span('https://a.com', style).children!.single;
      final second = links.span('https://a.com', style).children!.single;
      expect(
        (first as TextSpan).recognizer,
        same((second as TextSpan).recognizer),
      );
      expect(first.recognizer, isA<TapGestureRecognizer>());
    });
  });

  testWidgets('MessageLinkScope drops its recognizers with the widget', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 14);
    GestureRecognizer? recognizerOf(TextSpan span) =>
        (span.children!.single as TextSpan).recognizer;

    late MessageLinks links;
    late GestureRecognizer? before;
    await tester.pumpWidget(
      MaterialApp(
        home: MessageLinkScope(
          builder: (context, scoped) {
            links = scoped;
            final span = scoped.span('https://a.com', style);
            before = recognizerOf(span);
            return Text.rich(span);
          },
        ),
      ),
    );

    expect(recognizerOf(links.span('https://a.com', style)), same(before));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(
      recognizerOf(links.span('https://a.com', style)),
      isNot(same(before)),
    );
  });

  group('MessageBubble', () {
    Future<void> pumpBubble(WidgetTester tester, String text) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MessageBubble(author: 'Ada', text: text, timestamp: '10:00'),
          ),
        ),
      );
      await tester.pump();
    }

    void tapLinks(WidgetTester tester) {
      for (final widget in tester.widgetList<RichText>(
        find.descendant(
          of: find.byType(MarkdownBody),
          matching: find.byType(RichText),
        ),
      )) {
        widget.text.visitChildren((span) {
          if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
            (span.recognizer! as TapGestureRecognizer).onTap?.call();
          }
          return true;
        });
      }
    }

    testWidgets('opens a Markdown link', (tester) async {
      await pumpBubble(tester, '[docs](https://example.com/md)');
      tapLinks(tester);
      expect(opened, [Uri.parse('https://example.com/md')]);
    });

    testWidgets('opens a bare URL', (tester) async {
      await pumpBubble(tester, 'see https://example.com/bare now');
      tapLinks(tester);
      expect(opened, [Uri.parse('https://example.com/bare')]);
    });

    testWidgets('does not open a refused scheme', (tester) async {
      await pumpBubble(tester, '[x](file:///etc/hosts)');
      tapLinks(tester);
      expect(opened, isEmpty);
    });
  });
}
