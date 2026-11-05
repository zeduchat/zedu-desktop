import 'dart:async';

import 'package:zedu/core/core.dart';

class ChatWebsocketMessage {
  final String groupDmId;
  final String text;
  final String authorName;
  final DateTime timestamp;

  const ChatWebsocketMessage({
    required this.groupDmId,
    required this.text,
    required this.authorName,
    required this.timestamp,
  });
}

/// Real-time messages for group DMs.
///
/// There is no group DM socket on the server yet, so [messageStream] only
/// carries what [receive] is given. It used to invent a "Mock Member" message
/// every 15 seconds, which showed up as real messages in people's group DMs.
class ChatWebsocketService {
  final _messageController = StreamController<ChatWebsocketMessage>.broadcast();
  List<String> _activeGroupDmIds = const [];
  bool _isDisposed = false;

  Stream<ChatWebsocketMessage> get messageStream => _messageController.stream;
  bool get isDisposed => _isDisposed;

  /// Nothing is scheduled any more: there is no simulated connection delay.
  bool get hasPendingConnect => false;

  /// The group DMs this client is in, for when a real socket subscribes to them.
  List<String> get activeGroupDmIds => List.unmodifiable(_activeGroupDmIds);

  void connect(List<String> activeGroupDmIds) {
    if (_isDisposed) return;
    _activeGroupDmIds = List.of(activeGroupDmIds);
  }

  void disconnect() {
    _activeGroupDmIds = const [];
  }

  /// Delivers a message that arrived from the server to the listeners.
  void receive(ChatWebsocketMessage message) {
    if (_isDisposed || _messageController.isClosed) return;
    _messageController.add(message);
  }

  void sendMessage(String groupDmId, String text) {
    // No group DM socket on the server yet: sending is handled by the caller.
  }

  void dispose() {
    _isDisposed = true;
    _activeGroupDmIds = const [];
    if (!_messageController.isClosed) {
      _messageController.close();
    }
  }
}

final chatWebsocketProvider = Provider<ChatWebsocketService>((ref) {
  final service = ChatWebsocketService();
  ref.onDispose(service.dispose);
  return service;
});
