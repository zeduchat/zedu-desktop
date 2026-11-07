/// Turns a conversation into a file the user can keep: plain text for any
/// editor, or Markdown that keeps the formatting the chat renders.
///
/// Kept free of Flutter imports so the formatting can be unit tested without a
/// widget tree; the dialog only supplies the messages and the file name.
library;

enum TranscriptFormat {
  plainText('Plain text', '.txt', 'txt'),
  markdown('Markdown', '.md', 'md');

  const TranscriptFormat(this.label, this.extension, this.fileType);

  final String label;
  final String extension;

  /// Extension without the dot, for the platform save dialog's filter.
  final String fileType;
}

class TranscriptAttachment {
  const TranscriptAttachment({required this.name, this.link = ''});

  final String name;
  final String link;
}

class TranscriptMessage {
  const TranscriptMessage({
    required this.sender,
    required this.sentAt,
    this.content = '',
    this.attachments = const [],
  });

  final String sender;
  final DateTime sentAt;

  /// The message body as Markdown, the same text the chat bubble renders.
  final String content;
  final List<TranscriptAttachment> attachments;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// `5 Nov 2026, 9:05 AM`, the stamp shown next to each message.
String transcriptTimestamp(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = _twoDigits(local.minute);
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${local.day} ${_months[local.month - 1]} ${local.year}, '
      '$hour:$minute $period';
}

/// `ada-lovelace-transcript-2026-11-05.txt`, safe on every desktop platform.
String transcriptFileName(
  String conversationName,
  TranscriptFormat format,
  DateTime exportedAt,
) {
  final slug = conversationName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final local = exportedAt.toLocal();
  final date =
      '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
  return '${slug.isEmpty ? 'conversation' : slug}-transcript-$date'
      '${format.extension}';
}

/// Builds the file contents. Messages are written oldest first, whatever order
/// they arrive in, and an empty conversation still produces a readable file.
String formatTranscript({
  required String conversationName,
  required List<TranscriptMessage> messages,
  required TranscriptFormat format,
  required DateTime exportedAt,
}) {
  final ordered = [...messages]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  final count = ordered.length;
  final countLine = count == 1 ? '1 message' : '$count messages';

  return switch (format) {
    TranscriptFormat.plainText => _plainText(
      conversationName,
      ordered,
      exportedAt,
      countLine,
    ),
    TranscriptFormat.markdown => _markdown(
      conversationName,
      ordered,
      exportedAt,
      countLine,
    ),
  };
}

String _plainText(
  String conversationName,
  List<TranscriptMessage> messages,
  DateTime exportedAt,
  String countLine,
) {
  final out = StringBuffer()
    ..writeln('Conversation with $conversationName')
    ..writeln('Exported ${transcriptTimestamp(exportedAt)} · $countLine')
    ..writeln('-' * 48)
    ..writeln();

  if (messages.isEmpty) {
    out.writeln('No messages in this conversation.');
    return out.toString();
  }

  for (final message in messages) {
    out
      ..writeln('${message.sender} · ${transcriptTimestamp(message.sentAt)}')
      ..writeln();
    final body = _plainTextBody(message.content);
    if (body.isNotEmpty) {
      out
        ..writeln(body)
        ..writeln();
    }
    for (final attachment in message.attachments) {
      out.writeln('[Attachment] ${attachment.name}');
    }
    if (message.attachments.isNotEmpty) out.writeln();
  }
  return out.toString();
}

String _markdown(
  String conversationName,
  List<TranscriptMessage> messages,
  DateTime exportedAt,
  String countLine,
) {
  final out = StringBuffer()
    ..writeln('# Conversation with $conversationName')
    ..writeln()
    ..writeln('_Exported ${transcriptTimestamp(exportedAt)} · ${countLine}_')
    ..writeln();

  if (messages.isEmpty) {
    out.writeln('_No messages in this conversation._');
    return out.toString();
  }

  for (final message in messages) {
    out
      ..writeln('## ${message.sender} · ${transcriptTimestamp(message.sentAt)}')
      ..writeln();
    final body = message.content.trim();
    if (body.isNotEmpty) {
      out
        ..writeln(body)
        ..writeln();
    }
    for (final attachment in message.attachments) {
      final link = attachment.link.trim();
      out.writeln(
        link.isEmpty
            ? '- Attachment: ${attachment.name}'
            : '- [${attachment.name}]($link)',
      );
    }
    if (message.attachments.isNotEmpty) out.writeln();
  }
  return out.toString();
}

/// Flattens the inline Markdown the chat renders into readable text. Only the
/// markers the chat itself produces are removed, so file names with
/// underscores or asterisks survive.
String _plainTextBody(String markdown) {
  var text = markdown.replaceAllMapped(
    RegExp(r'^#{1,6}\s*', multiLine: true),
    (_) => '',
  );
  text = text.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\(([^)]*)\)'),
    (m) => (m[1] ?? '').isEmpty ? m[2]! : '${m[1]} (${m[2]})',
  );
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\(([^)]*)\)'),
    (m) => '${m[1]} (${m[2]})',
  );
  text = text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!);
  text = text.replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m[1]!);
  text = text.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!);
  text = text.replaceAllMapped(
    RegExp(r'(?<![\w*])\*([^*\n]+)\*(?![\w*])'),
    (m) => m[1]!,
  );
  return text.trim();
}
