import 'dart:convert';

/// What kind of conversation a notification came from.
enum AppNotificationKind { directMessage, groupDirectMessage, channel, other }

/// One entry of the notifications feed (`GET /organisations/{orgId}/users/
/// onesignal`), the same list Zedu web shows on its Notifications page.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.avatarUrl = '',
    this.sentAt,
    this.serverRead = false,
    this.status = '',
    this.notificationType = '',
    this.channelType = '',
    this.section = '',
    this.channelId = '',
    this.channelName = '',
    this.participantId = '',
    this.senderName = '',
    this.threadId = '',
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final payload = _payload(json);
    String field(Map<String, dynamic> map, List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is num) return value.toString();
      }
      return '';
    }

    final status = field(json, ['status']);
    return AppNotification(
      id: field(json, ['id', 'message_id', 'messages_id']),
      title: field(json, ['title']),
      message: field(json, ['message', 'body', 'content']),
      avatarUrl: field(json, ['avatar_url']).isNotEmpty
          ? field(json, ['avatar_url'])
          : field(payload, ['avatar_url', 'default_avatar_url']),
      sentAt: parseNotificationTime(
        json['sent_at'] ??
            json['created_at'] ??
            json['createdAt'] ??
            json['timestamp'] ??
            payload['sent_at'] ??
            payload['created_at'],
      ),
      serverRead:
          json['is_read'] == true ||
          json['read'] == true ||
          status.toLowerCase() == 'read',
      status: status,
      notificationType: field(payload, ['notification_type']).toLowerCase(),
      channelType: field(payload, [
        'channel_type',
      ]).toLowerCase().replaceAll(RegExp(r'[\s_-]'), ''),
      section: field(payload, ['section']).toLowerCase(),
      channelId: field(payload, ['channel_id', 'channels_id']),
      channelName: field(payload, ['channel_name']),
      participantId: field(payload, ['participant_id', 'sender_id']),
      senderName: field(payload, ['sender_name']),
      threadId: field(payload, ['thread_id', 'message_id']),
    );
  }

  final String id;
  final String title;
  final String message;
  final String avatarUrl;
  final DateTime? sentAt;

  /// Whether the server already marks it read.
  final bool serverRead;
  final String status;
  final String notificationType;
  final String channelType;
  final String section;
  final String channelId;
  final String channelName;
  final String participantId;
  final String senderName;
  final String threadId;

  /// The sender shown in the detail pane.
  String get displaySender => senderName.isNotEmpty
      ? senderName
      : title.isNotEmpty
      ? title
      : 'Unknown';

  /// Same rules as zedu-fe's `resolveNotificationRoute`.
  AppNotificationKind get kind {
    final isGroupDm =
        notificationType == 'groupdm' ||
        notificationType == 'group_dm' ||
        channelType == 'groupdm' ||
        channelType == 'groupdms';
    if (isGroupDm) return AppNotificationKind.groupDirectMessage;
    if (notificationType == 'dm' ||
        section == 'dm_channels_section' ||
        channelType == 'dm') {
      return AppNotificationKind.directMessage;
    }
    if (channelId.isNotEmpty) return AppNotificationKind.channel;
    return AppNotificationKind.other;
  }

  bool get isDirect =>
      kind == AppNotificationKind.directMessage ||
      kind == AppNotificationKind.groupDirectMessage;

  /// The label above the message in the detail pane, as on web.
  String get typeLabel => switch (notificationType) {
    'dm' => 'Direct message',
    'channel' => 'Channel message',
    'mention' => 'Mention',
    _ => isDirect ? 'Direct message' : 'Message',
  };

  /// Whether "Open conversation" has somewhere to go.
  bool get canOpen => channelId.isNotEmpty;

  /// The payload, which the feed sends as an object or a JSON string, under
  /// `payload` or `data`, sometimes with a nested `data` object.
  static Map<String, dynamic> _payload(Map<String, dynamic> json) {
    Map<String, dynamic> asMap(Object? value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      if (value is String && value.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } on FormatException {
          return const {};
        }
      }
      return const {};
    }

    final base = {...asMap(json['data']), ...asMap(json['payload'])};
    final nested = asMap(base['data']);
    return {...base, ...nested};
  }
}

/// Parses the feed's timestamps: ISO strings, or Unix seconds/milliseconds as
/// numbers or numeric strings (zedu-fe's `getNotificationTimestamp`).
DateTime? parseNotificationTime(Object? raw) {
  if (raw == null) return null;
  num? numeric;
  if (raw is num) numeric = raw;
  if (raw is String) {
    numeric = num.tryParse(raw.trim());
    if (numeric == null) return DateTime.tryParse(raw.trim())?.toLocal();
  }
  if (numeric == null || numeric <= 0) return null;
  final millis = numeric >= 1e9 && numeric < 1e11 ? numeric * 1000 : numeric;
  return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
}
