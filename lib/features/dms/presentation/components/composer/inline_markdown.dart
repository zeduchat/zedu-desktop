import 'package:zedu/core/core.dart';

/// Inline Markdown used by DM messages: `*italic*`, `**bold**`,
/// `~~strike~~`, `` `code` `` and `[label](https://url)` links.
///
/// Italic is tried first and may contain `**bold**` pairs, so text that was
/// made bold and italic (`***word***`, from either toolbar order) is read as
/// italic around bold instead of bold around a stray `*`. A lone `**` is the
/// empty italic the toolbar inserts with no selection. Links are tried last
/// so inline code stays literal even when it contains something link-shaped.
final _inlineMarkdown = RegExp(
  r'(?<!\*)\*(?<italic>(?:\*\*.+?\*\*|[^*])+?)\*(?!\*)'
  r'|\*\*(?<bold>.*?)\*\*(?!\*)'
  r'|(?<!\*)\*\*(?!\*)'
  r'|~~(?<strike>.*?)~~'
  r'|`(?<code>.*?)`'
  r'|\[(?<label>[^\]\n]+?)\]\((?<url>https?://[^\s)]+)\)',
  dotAll: true,
);

/// Builds a span for [text] with inline Markdown applied on top of [style].
///
/// Formatting nests, so `~~**word**~~` is struck through and bold. Inline
/// code stays literal. With [keepMarkers] the markers stay in the span but
/// are invisible, so the span's text matches [text] (needed by the composer,
/// whose cursor offsets index into the raw text); otherwise they are dropped.
///
/// Each formatted token is one span whose children are its (hidden) opening
/// marker, its text and its closing marker. [plainText] builds the spans for
/// text outside inline code, for example to make links tappable. [link]
/// builds the span for a `[label](url)` link, with the label's formatted
/// spans as children; without it links render as their raw text.
TextSpan buildInlineMarkdownSpan(
  String text,
  TextStyle style, {
  bool keepMarkers = false,
  TextSpan Function(String text, TextStyle style)? plainText,
  TextSpan Function(
    String label,
    String url,
    TextStyle style,
    List<InlineSpan> children,
  )?
  link,
}) {
  if (text.isEmpty) return TextSpan(style: style, text: '');
  return TextSpan(
    style: style,
    children: _inlineSpans(
      text,
      style,
      keepMarkers,
      plainText ?? (text, style) => TextSpan(text: text, style: style),
      link,
    ),
  );
}

List<InlineSpan> _inlineSpans(
  String text,
  TextStyle style,
  bool keepMarkers,
  TextSpan Function(String text, TextStyle style) plainText,
  TextSpan Function(
    String label,
    String url,
    TextStyle style,
    List<InlineSpan> children,
  )?
  link,
) {
  final spans = <InlineSpan>[];
  final hiddenStyle = style.copyWith(color: Colors.transparent, fontSize: 0.01);

  void addToken(String marker, String inner, TextStyle innerStyle, bool nest) {
    final parts = <InlineSpan>[
      if (keepMarkers) TextSpan(text: marker, style: hiddenStyle),
    ];
    if (inner.isNotEmpty) {
      if (nest) {
        final nested = _inlineSpans(
          inner,
          innerStyle,
          keepMarkers,
          plainText,
          link,
        );
        parts.add(
          nested.length == 1 ? nested.single : TextSpan(children: nested),
        );
      } else {
        parts.add(TextSpan(text: inner, style: innerStyle));
      }
    }
    if (keepMarkers) parts.add(TextSpan(text: marker, style: hiddenStyle));
    spans.add(TextSpan(children: parts));
  }

  var lastEnd = 0;
  for (final match in _inlineMarkdown.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(plainText(text.substring(lastEnd, match.start), style));
    }

    final italic = match.namedGroup('italic');
    final bold = match.namedGroup('bold');
    final strike = match.namedGroup('strike');
    final code = match.namedGroup('code');
    final label = match.namedGroup('label');
    final url = match.namedGroup('url');
    if (italic != null) {
      addToken('*', italic, style.copyWith(fontStyle: FontStyle.italic), true);
    } else if (bold != null) {
      addToken('**', bold, style.copyWith(fontWeight: FontWeight.bold), true);
    } else if (strike != null) {
      addToken(
        '~~',
        strike,
        style.copyWith(decoration: TextDecoration.lineThrough),
        true,
      );
    } else if (code != null) {
      addToken(
        '`',
        code,
        style.copyWith(
          fontFamily: 'monospace',
          backgroundColor: const Color(0x1A6458F5),
          color: const Color(0xFF6458F5),
        ),
        false,
      );
    } else if (label != null && url != null) {
      final nested = label.isEmpty
          ? const <InlineSpan>[]
          : _inlineSpans(label, style, keepMarkers, plainText, link);
      if (keepMarkers) {
        spans.add(
          TextSpan(
            children: [
              TextSpan(text: '[', style: hiddenStyle),
              ...nested,
              TextSpan(text: ']($url)', style: hiddenStyle),
            ],
          ),
        );
      } else if (link != null) {
        spans.add(link(label, url, style, nested));
      } else {
        spans.add(TextSpan(text: match.group(0), style: style));
      }
    } else if (keepMarkers) {
      // Empty italic (`**`): nothing to show but the hidden markers.
      spans.add(TextSpan(text: match.group(0), style: hiddenStyle));
    } else {
      // A lone `**` in a message formats nothing, so it is literal text, as
      // in `2 ** 3` or `**/*.dart` (Ziki #2879).
      spans.add(plainText(match.group(0)!, style));
    }

    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(plainText(text.substring(lastEnd), style));
  }
  return spans;
}
