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
///
/// With [mentions], each `@name`, `@channel` or `@here` outside inline code
/// and links becomes its own highlighted span, coloured as on web.
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
  MentionHighlight? mentions,
}) {
  if (text.isEmpty) return TextSpan(style: style, text: '');
  final plain =
      plainText ?? (text, style) => TextSpan(text: text, style: style);
  return TextSpan(
    style: style,
    children: _inlineSpans(
      text,
      style,
      keepMarkers,
      mentions == null
          ? plain
          : (text, style) => _mentionSpans(text, style, plain, mentions),
      link,
    ),
  );
}

/// How [buildInlineMarkdownSpan] highlights @mentions.
class MentionHighlight {
  const MentionHighlight({required this.colors, this.selfUsername});

  final AppPalette colors;

  /// The signed-in user's username, whose mentions get the yellow highlight.
  final String? selfUsername;
}

/// `@name` not glued to a word or another `@`, so `ada@example.com` is not a
/// mention. Names end on a letter, digit or `_`, leaving out a trailing `.`.
final _mention = RegExp(r'(?<![\w@])@([A-Za-z0-9_](?:[\w.-]*[A-Za-z0-9_])?)');

const _channelMentions = {'channel', 'here', 'everyone'};

TextSpan _mentionSpans(
  String text,
  TextStyle style,
  TextSpan Function(String text, TextStyle style) plainText,
  MentionHighlight mentions,
) {
  final colors = mentions.colors;
  final self = mentions.selfUsername?.trim().toLowerCase();
  final children = <InlineSpan>[];
  var last = 0;
  for (final match in _mention.allMatches(text)) {
    // An @ inside a URL (`https://x.com/@ada`) belongs to the link.
    final wordStart = text.lastIndexOf(RegExp(r'\s'), match.start) + 1;
    final word = text.substring(wordStart, match.start).toLowerCase();
    if (word.contains('://') || word.startsWith('www.')) continue;

    final name = match.group(1)!.toLowerCase();
    final isChannel = _channelMentions.contains(name);
    final isSelf = self != null && self.isNotEmpty && name == self;
    if (match.start > last) {
      children.add(plainText(text.substring(last, match.start), style));
    }
    children.add(
      TextSpan(
        text: match.group(0),
        style: style.copyWith(
          color: isChannel ? colors.channelMention : colors.mention,
          backgroundColor: isChannel || isSelf
              ? colors.mentionHighlightBg
              : colors.mentionBg,
          // Medium as on web, without undoing bold around the mention.
          fontWeight: style.fontWeight == FontWeight.bold
              ? FontWeight.bold
              : FontWeight.w500,
        ),
      ),
    );
    last = match.end;
  }
  if (children.isEmpty) return plainText(text, style);
  if (last < text.length) children.add(plainText(text.substring(last), style));
  return TextSpan(children: children);
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
    }

    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(plainText(text.substring(lastEnd), style));
  }
  return spans;
}
