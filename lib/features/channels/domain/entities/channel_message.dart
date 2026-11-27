/// A single reaction (emoji) on a channel message, as returned by
/// `GET /threads/channels/{channel_id}`.
class ChannelReaction {
  final String emoji;
  final String reactionId;
  final int count;

  const ChannelReaction({
    required this.emoji,
    required this.reactionId,
    required this.count,
  });

  factory ChannelReaction.fromJson(Map<String, dynamic> json) {
    return ChannelReaction(
      emoji: json['reaction']?.toString() ?? '',
      reactionId: json['reaction_id']?.toString() ?? '',
      count: (json['reaction_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A top-level message in a channel, as returned by
/// `GET /threads/channels/{channel_id}`.
class ChannelMessage {
  /// The thread id from the backend. Null for a message the backend gave none.
  final String? id;
  final String senderName;
  final String? avatarUrl;
  final String text;
  final String rawContent;
  final DateTime? createdAt;
  final String? status;
  final List<dynamic> media;

  /// The message's thread id, which the edit and delete routes take.
  final String? threadId;

  /// Who sent it, so the current user's own messages can be edited.
  final String? userId;
  final List<ChannelReaction> reactions;

  /// The backend's message type: `thread` for a person's message, `system`
  /// for an automatic notice such as "mimi joined this channel".
  final String? type;

  const ChannelMessage({
    this.id,
    required this.senderName,
    required this.text,
    String? rawContent,
    this.avatarUrl,
    this.createdAt,
    this.status,

    this.media = const [],
    this.threadId,
    this.userId,
    this.reactions = const [],
    this.type,
  }) : rawContent = rawContent ?? text;

  static List<dynamic> mediaFrom(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<dynamic, dynamic>>().toList();
    }
    return const [];
  }

  /// Whether this is an automatic notice rather than something a person said.
  bool get isSystem => type == 'system';

  /// The text of a system notice split into plain text and the people it
  /// names, read from the mention spans the backend writes into it
  /// (`<span data-type="mention" data-id=".." data-label="..">@name</span>`).
  List<ChannelNoticePart> get noticeParts {
    final mentions = <ChannelNoticePart>[];
    // Each mention becomes a marker that the HTML cleanup keeps, so the text
    // around it is cleaned the same way as a normal message.
    final marked = rawContent.replaceAllMapped(_mentionSpan, (match) {
      final attributes = match[1]!;
      String? attribute(String name) =>
          RegExp('$name="([^"]*)"').firstMatch(attributes)?.group(1);
      final label =
          attribute('data-label') ??
          match[2]!.replaceAll(_htmlTag, '').replaceFirst(RegExp('^@'), '');
      final userId = attribute('data-id');
      mentions.add(
        ChannelNoticePart(
          text: _decodeHtmlEntities(label),
          userId: userId == null || userId.isEmpty
              ? null
              : _decodeHtmlEntities(userId),
          isMention: true,
        ),
      );
      return '$_mentionMarker${mentions.length - 1}$_mentionMarker';
    });
    if (mentions.isEmpty) return [ChannelNoticePart(text: text)];

    final parts = <ChannelNoticePart>[];
    final pieces = _cleanMessageText(marked).split(_mentionMarker);
    for (var i = 0; i < pieces.length; i++) {
      // Odd pieces sit between two markers: a mention's index.
      final index = i.isOdd ? int.tryParse(pieces[i]) : null;
      if (index != null && index < mentions.length) {
        parts.add(mentions[index]);
      } else if (pieces[i].isNotEmpty) {
        parts.add(ChannelNoticePart(text: pieces[i]));
      }
    }
    return parts;
  }

  /// A private-use character, which notice text does not contain.
  static const _mentionMarker = '\u{E000}';

  static final _mentionSpan = RegExp(
    r'<span\b([^>]*\bdata-type="mention"[^>]*)>(.*?)</span>',
    caseSensitive: false,
    dotAll: true,
  );

  /// Identifies this message when pages are merged, so a message that shows
  /// up on two pages is listed once. Falls back to the content for a message
  /// without an [id].
  String get dedupeKey =>
      id ?? '$senderName|${createdAt?.toIso8601String()}|$text';

  factory ChannelMessage.fromJson(Map<String, dynamic> json) {
    String? nonEmpty(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    final rawContent = json['message']?.toString() ?? '';
    return ChannelMessage(
      id: nonEmpty(json['thread_id']) ?? nonEmpty(json['id']),
      senderName:
          nonEmpty(json['full_name']) ??
          nonEmpty(json['sender_name']) ??
          nonEmpty(json['username']) ??
          'Unknown',
      avatarUrl:
          nonEmpty(json['avatar_url']) ?? nonEmpty(json['default_avatar_url']),
      // Messages sent from the web app arrive as HTML (`<p>hi</p>`).
      rawContent: rawContent,

      text: _cleanMessageText(json['message']?.toString() ?? ''),

      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal(),
      status: json['status']?.toString(),
      media: mediaFrom(json['media'] ?? json['files'] ?? json['attachments']),
      threadId: nonEmpty(json['thread_id']) ?? nonEmpty(json['id']),
      userId: nonEmpty(json['user_id']),
      reactions: [
        for (final entry in (json['reactions'] as List? ?? const []))
          if (entry is Map<String, dynamic>) ChannelReaction.fromJson(entry),
      ],
      type: nonEmpty(json['type']),
    );
  }

  static final _htmlBlock = RegExp(
    r'^\s*<(p|div|blockquote|pre|h[1-6]|ul|ol|table)\b',
    caseSensitive: false,
  );

  static final _htmlTag = RegExp(
    r'<(/?)(p|div|blockquote|pre|h[1-6]|ul|ol|li|strong|b|em|i|s|del|strike|code|a|span|br|hr|table|tbody|thead|tr|td|th)\b[^>]*>',
    caseSensitive: false,
  );

  static String _cleanMessageText(String raw) {
    if (!_htmlBlock.hasMatch(raw)) {
      return _decodeHtmlEntities(raw).trim();
    }
    return _decodeHtmlEntities(
      raw
          .replaceAll(
            RegExp(
              r'</(p|div|li)>\s*<(p|div|li|ul|ol)\b[^>]*>|<br\s*/?>',
              caseSensitive: false,
            ),
            '\n',
          )
          .replaceAll(_htmlTag, ''),
    ).trim();
  }

  /// Decodes in a single pass, so `&amp;lt;` stays the literal text `&lt;`.
  static String _decodeHtmlEntities(String text) {
    const named = {
      'nbsp': ' ',
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
    };

    return text.replaceAllMapped(
      RegExp(r'&(?:#(\d+)|#[xX]([0-9a-fA-F]+)|(nbsp|amp|lt|gt|quot|apos));'),
      (match) {
        final name = match[3];
        if (name != null) return named[name]!;

        final code = match[1] != null
            ? int.tryParse(match[1]!)
            : int.tryParse(match[2]!, radix: 16);
        final isCharacter =
            code != null &&
            code > 0 &&
            code <= 0x10FFFF &&
            (code < 0xD800 || code > 0xDFFF);
        return isCharacter ? String.fromCharCode(code) : match[0]!;
      },
    );
  }
}

/// A piece of a system notice: plain text, or a person the notice names.
class ChannelNoticePart {
  final String text;

  /// The named person's user id, when the notice gave one.
  final String? userId;

  /// Whether this piece names a person rather than being plain text.
  final bool isMention;

  const ChannelNoticePart({
    required this.text,
    this.userId,
    this.isMention = false,
  });
}
