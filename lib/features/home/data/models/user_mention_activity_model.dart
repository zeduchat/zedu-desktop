/// A message that mentions the signed-in user.
class UserMentionActivityModel {
  const UserMentionActivityModel({
    required this.id,
    required this.messageId,
    required this.channelId,
    required this.channelName,
    required this.senderName,
    required this.content,
    this.senderAvatarUrl,
    this.createdAt,
  });

  final String id;
  final String messageId;
  final String channelId;
  final String channelName;
  final String senderName;
  final String content;
  final String? senderAvatarUrl;
  final DateTime? createdAt;

  factory UserMentionActivityModel.fromJson(Map<String, dynamic> json) {
    return UserMentionActivityModel(
      id: _asString(json['id']),
      messageId: _asString(json['messageId'] ?? json['message_id']),
      channelId: _asString(json['channelId'] ?? json['channel_id']),
      channelName: _asString(json['channelName'] ?? json['channel_name']),
      senderName: _asString(json['senderName'] ?? json['sender_name']),
      content: _asString(json['content'] ?? json['message']),
      senderAvatarUrl: _asNullableString(
        json['senderAvatarUrl'] ?? json['sender_avatar_url'],
      ),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'messageId': messageId,
    'channelId': channelId,
    'channelName': channelName,
    'senderName': senderName,
    'content': content,
    if (senderAvatarUrl != null) 'senderAvatarUrl': senderAvatarUrl,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}

String _asString(Object? value) => value?.toString() ?? '';

String? _asNullableString(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
