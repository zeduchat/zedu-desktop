import 'package:zedu/core/core.dart';

/// The message a mounted [DmChatArea] should scroll to once its history is
/// loaded. Set by the chat deep link listener right before it selects the
/// conversation; the matching chat area clears it after jumping.
class PendingMessageJump {
  const PendingMessageJump({required this.channelId, required this.messageId});

  final String channelId;
  final String messageId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingMessageJump &&
          other.channelId == channelId &&
          other.messageId == messageId;

  @override
  int get hashCode => Object.hash(channelId, messageId);
}

final pendingMessageJumpProvider = StateProvider<PendingMessageJump?>(
  (ref) => null,
);
