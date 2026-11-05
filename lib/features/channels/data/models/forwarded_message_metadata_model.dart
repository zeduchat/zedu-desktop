/// Metadata attached to a message that was forwarded from another channel or
/// direct message.
class ForwardedMessageMetadataModel {
  const ForwardedMessageMetadataModel({
    required this.originalMessageId,
    required this.originalSenderName,
    required this.originalChannelName,
    required this.originalCreatedAt,
    this.isThread = false,
  });

  final String originalMessageId;
  final String originalSenderName;
  final String originalChannelName;
  final DateTime? originalCreatedAt;
  final bool isThread;

  factory ForwardedMessageMetadataModel.fromJson(Map<String, dynamic> json) {
    return ForwardedMessageMetadataModel(
      originalMessageId: _asString(
        json['originalMessageId'] ?? json['original_message_id'],
      ),
      originalSenderName: _asString(
        json['originalSenderName'] ?? json['original_sender_name'],
      ),
      originalChannelName: _asString(
        json['originalChannelName'] ?? json['original_channel_name'],
      ),
      originalCreatedAt: _parseDate(
        json['originalCreatedAt'] ?? json['original_created_at'],
      ),
      isThread: _asBool(json['isThread'] ?? json['is_thread']),
    );
  }

  Map<String, dynamic> toJson() => {
    'originalMessageId': originalMessageId,
    'originalSenderName': originalSenderName,
    'originalChannelName': originalChannelName,
    if (originalCreatedAt != null)
      'originalCreatedAt': originalCreatedAt!.toIso8601String(),
    'isThread': isThread,
  };
}

String _asString(Object? value) => value?.toString() ?? '';

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
