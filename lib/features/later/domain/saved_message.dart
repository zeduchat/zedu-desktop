class SavedMessage {
  const SavedMessage({
    required this.id,
    required this.channelId,
    required this.preview,
    this.channelName = '',
    this.sender = '',
    this.isDm = false,
  });
  final String id;
  final String channelId;
  final String preview;
  final String channelName;
  final String sender;
  final bool isDm;
  factory SavedMessage.fromJson(Map<String, dynamic> json) => SavedMessage(
    id: (json['thread_id'] ?? json['message_id'] ?? json['id'] ?? '')
        .toString(),
    channelId: (json['channels_id'] ?? json['channel_id'] ?? '').toString(),
    preview: (json['content'] ?? json['message'] ?? '').toString(),
    channelName: (json['channel_name'] ?? '').toString(),
    sender: (json['full_name'] ?? json['sender_name'] ?? '').toString(),
    isDm:
        (json['channel_type'] ?? '').toString().toLowerCase().contains(
          'direct',
        ) ||
        ['dm', 'group_dm'].contains(json['channel_type']),
  );
}
