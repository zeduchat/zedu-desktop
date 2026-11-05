import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('htmlMessageToMarkdown', () {
    test('leaves Markdown from desktop unchanged', () {
      const text = '**bold** and *italic* & a < b\n\n---\nnext';
      expect(htmlMessageToMarkdown(text), text);
    });

    test('removes a paragraph wrapper', () {
      expect(htmlMessageToMarkdown('<p>Hello</p>'), 'Hello');
    });

    test('turns an empty paragraph into no text', () {
      expect(htmlMessageToMarkdown('<p></p>'), '');
    });

    test('keeps inline formatting as Markdown', () {
      expect(
        htmlMessageToMarkdown(
          '<p><strong>Hi</strong> <em>there</em> <s>old</s> <code>x</code></p>',
        ),
        '**Hi** *there* ~~old~~ `x`',
      );
    });

    test('decodes entities', () {
      expect(
        htmlMessageToMarkdown(
          '<p>Tom &amp; Jerry &lt;3 &quot;hi&quot; &#39;'
          'x&#39; &#x1F600;&nbsp;!</p>',
        ),
        'Tom & Jerry <3 "hi" \'x\' 😀 !',
      );
    });

    test('puts paragraphs and line breaks on their own lines', () {
      expect(
        htmlMessageToMarkdown(
          '<p>one<br>two</p><p>three</p><p></p><p>four</p>',
        ),
        'one\ntwo\nthree\n\nfour',
      );
    });

    test('shows bullet and numbered lists', () {
      expect(
        htmlMessageToMarkdown(
          '<ul><li><p>a</p></li><li><p>b</p></li></ul>'
          '<ol><li>first</li><li>second</li></ol>',
        ),
        '• a\n• b\n1. first\n2. second',
      );
    });

    test('indents nested lists', () {
      expect(
        htmlMessageToMarkdown('<ul><li>a<ul><li>b</li></ul></li></ul>'),
        '• a\n  • b',
      );
    });

    test('ignores whitespace between tags', () {
      expect(
        htmlMessageToMarkdown('<ul>\n  <li>a</li>\n  <li>b</li>\n</ul>'),
        '• a\n• b',
      );
    });

    test('keeps link text and drops unknown tags', () {
      expect(
        htmlMessageToMarkdown(
          '<p>See <a href="https://zedu.chat">this</a> <span>now</span></p>',
        ),
        'See this now',
      );
    });
  });
}
