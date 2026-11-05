final _htmlTag = RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>');
final _htmlEntity = RegExp(r'&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
};

const _inlineMarkers = {
  'strong': '**',
  'b': '**',
  'em': '*',
  'i': '*',
  's': '~~',
  'del': '~~',
  'strike': '~~',
  'code': '`',
};

const _blockTags = {
  'p',
  'div',
  'blockquote',
  'pre',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
};

/// Turns message content sent from web or mobile, which arrives as HTML
/// (`<p>Hello <strong>you</strong></p>`), into the Markdown the desktop chat
/// renders (`Hello **you**`). Content without HTML tags, such as messages sent
/// from desktop, is returned unchanged.
String htmlMessageToMarkdown(String content) {
  if (!_htmlTag.hasMatch(content)) return content;

  final out = StringBuffer();
  // Ordered-list counters for the open lists; null marks a bullet list.
  final lists = <int?>[];
  // True right after a list marker, so the item's paragraph stays on its line.
  var afterMarker = false;

  bool atLineStart() => out.isEmpty || out.toString().endsWith('\n');

  void newLine() {
    if (!atLineStart() && !afterMarker) out.write('\n');
  }

  void writeText(String text) {
    // Whitespace that only lays out the markup (`</li>\n  <li>`) is not text.
    if (text.trim().isEmpty && (text.contains('\n') || atLineStart())) return;
    if (text.trim().isEmpty && afterMarker) return;
    final collapsed = text.replaceAll(RegExp(r'\s*\n\s*'), ' ');
    out.write(_decodeEntities(collapsed));
    afterMarker = false;
  }

  var index = 0;
  for (final match in _htmlTag.allMatches(content)) {
    writeText(content.substring(index, match.start));
    index = match.end;

    final closing = match.group(1) == '/';
    final tag = match.group(2)!.toLowerCase();
    final marker = _inlineMarkers[tag];

    if (marker != null) {
      out.write(marker);
    } else if (tag == 'br') {
      out.write('\n');
      afterMarker = false;
    } else if (tag == 'hr') {
      out.write(atLineStart() ? '\n---\n' : '\n\n---\n');
      afterMarker = false;
    } else if (tag == 'ul' || tag == 'ol') {
      if (closing) {
        if (lists.isNotEmpty) lists.removeLast();
      } else {
        lists.add(tag == 'ol' ? 0 : null);
      }
      newLine();
    } else if (tag == 'li' && !closing) {
      newLine();
      final depth = lists.isEmpty ? 1 : lists.length;
      var bullet = '•';
      if (lists.isNotEmpty && lists.last != null) {
        lists[lists.length - 1] = lists.last! + 1;
        bullet = '${lists.last}.';
      }
      out.write('${'  ' * (depth - 1)}$bullet ');
      afterMarker = true;
    } else if (_blockTags.contains(tag)) {
      if (closing) {
        out.write('\n');
        afterMarker = false;
      } else {
        newLine();
      }
    }
  }
  writeText(content.substring(index));

  return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _decodeEntities(String text) {
  return text.replaceAllMapped(_htmlEntity, (match) {
    final name = match.group(1)!;
    if (name.startsWith('#')) {
      final hex = name.length > 1 && (name[1] == 'x' || name[1] == 'X');
      final code = int.tryParse(
        name.substring(hex ? 2 : 1),
        radix: hex ? 16 : 10,
      );
      if (code == null || code > 0x10FFFF) return match.group(0)!;
      return String.fromCharCode(code);
    }
    return _namedEntities[name.toLowerCase()] ?? match.group(0)!;
  });
}
