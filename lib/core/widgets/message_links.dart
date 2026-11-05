import 'package:flutter/gestures.dart';
import 'package:zedu/core/core.dart';

const _allowedLinkSchemes = {'http', 'https'};

final _messageUrlPattern = RegExp(
  r'''(?<![\w@/.])(?:https?://|www\.)[^\s<>"]+''',
  caseSensitive: false,
);

/// Opens a link in the default browser. Tests replace this to record the call.
@visibleForTesting
Future<bool> Function(Uri uri) messageLinkLauncher = _launchInBrowser;

Future<bool> _launchInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The [Uri] to open for [raw], or null when it must not be opened. Message
/// text is written by other users, so only web links are allowed: other schemes
/// would reach the operating system's protocol handlers.
Uri? messageLinkUri(String raw) {
  final text = raw.trim();
  final isBareWww = text.toLowerCase().startsWith('www.');
  final uri = Uri.tryParse(isBareWww ? 'https://$text' : text);
  if (uri == null || uri.host.isEmpty) return null;
  return _allowedLinkSchemes.contains(uri.scheme.toLowerCase()) ? uri : null;
}

/// Opens [raw] when [messageLinkUri] allows it, and returns whether it opened.
Future<bool> openMessageLink(String raw) async {
  final uri = messageLinkUri(raw);
  if (uri == null) return false;
  try {
    return await messageLinkLauncher(uri);
  } catch (error) {
    AppLogger.w('Could not open a message link', error: error);
    return false;
  }
}

/// Removes sentence punctuation that followed a URL, keeping a closing bracket
/// only when the URL also has the opening one.
String _trimMessageUrl(String url) {
  const brackets = {')': '(', ']': '[', '}': '{'};
  var end = url.length;
  while (end > 0) {
    final last = url[end - 1];
    final text = url.substring(0, end);
    final open = brackets[last];
    final unbalanced =
        open != null &&
        last.allMatches(text).length > open.allMatches(text).length;
    if (!unbalanced && !".,;:!?'".contains(last)) break;
    end--;
  }
  return url.substring(0, end);
}

/// Builds tappable text spans for the URLs in a message, and owns their gesture
/// recognizers. Get one from [MessageLinkScope], which disposes them.
class MessageLinks {
  final Map<String, TapGestureRecognizer> _recognizers = {};

  /// [text] in [style], with each allowed URL underlined and tappable.
  TextSpan span(String text, TextStyle style) {
    final children = <TextSpan>[];
    var last = 0;

    for (final match in _messageUrlPattern.allMatches(text)) {
      final url = _trimMessageUrl(match.group(0)!);
      if (messageLinkUri(url) == null) continue;
      if (match.start > last) {
        children.add(TextSpan(text: text.substring(last, match.start)));
      }
      children.add(
        TextSpan(
          text: url,
          style: style.copyWith(
            decoration: TextDecoration.combine([
              ?style.decoration,
              TextDecoration.underline,
            ]),
          ),
          recognizer: _recognizers.putIfAbsent(
            url,
            () => TapGestureRecognizer()..onTap = () => openMessageLink(url),
          ),
        ),
      );
      last = match.start + url.length;
    }

    if (children.isEmpty) return TextSpan(text: text, style: style);
    if (last < text.length) {
      children.add(TextSpan(text: text.substring(last)));
    }
    return TextSpan(style: style, children: children);
  }

  void _dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}

/// Keeps the [MessageLinks] of one message for as long as it is on screen.
class MessageLinkScope extends StatefulWidget {
  const MessageLinkScope({super.key, required this.builder});

  final Widget Function(BuildContext context, MessageLinks links) builder;

  @override
  State<MessageLinkScope> createState() => _MessageLinkScopeState();
}

class _MessageLinkScopeState extends State<MessageLinkScope> {
  final MessageLinks _links = MessageLinks();

  @override
  void dispose() {
    _links._dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _links);
}
