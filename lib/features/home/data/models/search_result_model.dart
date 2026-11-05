/// A single organisation message search hit.
///
/// The backend returns search results grouped by sender and channel; the data
/// source flattens those groups into one of these models per message. The
/// parser also accepts flat payloads so it stays useful for tests and for any
/// future endpoint that returns messages directly.
class SearchResultModel {
  const SearchResultModel({
    required this.id,
    required this.content,
    required this.channelId,
    required this.channelName,
    required this.senderName,
    this.senderAvatarUrl,
    this.createdAt,
  });

  final String id;
  final String content;
  final String channelId;
  final String channelName;
  final String senderName;
  final String? senderAvatarUrl;
  final DateTime? createdAt;

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    return SearchResultModel(
      id: _asString(json['id'] ?? json['message_id'] ?? json['messageId']),
      content: _asString(json['content'] ?? json['message']),
      channelId: _asString(json['channelId'] ?? json['channel_id']),
      channelName: _asString(json['channelName'] ?? json['channel_name']),
      senderName: _asString(
        json['senderName'] ?? json['sender_name'] ?? json['user_name'],
      ),
      senderAvatarUrl: _asNullableString(
        json['senderAvatarUrl'] ??
            json['sender_avatar_url'] ??
            json['avatar_url'],
      ),
      createdAt: _parseDate(
        json['createdAt'] ?? json['created_at'] ?? json['timestamp'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'channelId': channelId,
    'channelName': channelName,
    'senderName': senderName,
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
