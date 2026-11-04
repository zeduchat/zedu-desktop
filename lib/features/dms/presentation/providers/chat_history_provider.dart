import 'dart:io' show File;

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Everything one conversation's chat area renders from.
///
/// It is immutable: the notifier replaces it on every change, and that is what
/// rebuilds the widgets watching the family provider.
class ChatHistoryState {
  const ChatHistoryState({
    this.messages = const [],
    this.isLoading = true,
    this.hasMore = true,
    this.page = 1,
    this.editingMessageId,
  });

  final List<Map<String, dynamic>> messages;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? editingMessageId;

  ChatHistoryState copyWith({
    List<Map<String, dynamic>>? messages,
    bool? isLoading,
    bool? hasMore,
    int? page,
    String? editingMessageId,
    bool clearEditingMessageId = false,
  }) {
    return ChatHistoryState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      editingMessageId: clearEditingMessageId
          ? null
          : (editingMessageId ?? this.editingMessageId),
    );
  }
}

class ChatHistoryNotifier extends Notifier<ChatHistoryState> {
  ChatHistoryNotifier(this.channelId);

  final String channelId;

  /// Set of message IDs we have already seen. Used to detect truly-new messages
  /// so we don't re-fire a notification on every poll cycle.
  final Set<String> _seenIds = {};

  /// Keep track of the polling timer so we can cancel it on dispose.
  // ignore: cancel_subscriptions
  dynamic _pollingTimer;

  bool _isHistoryClearedLocally = false;

  final Map<String, Future<void>> _saveEditChains = {};

  /// What each message was sent with, so a retry sends it the same way.
  final Map<String, ({List<XFile>? media, bool isChannel})> _sendOptions = {};

  /// Ids of messages being deleted or already deleted, so polling and paging
  /// do not bring them back.
  final Set<String> _deletedIds = {};

  @override
  ChatHistoryState build() {
    ref.onDispose(_dispose);
    Future<void>.microtask(_loadInitial);
    return const ChatHistoryState();
  }

  void _dispose() {
    _pollingTimer?.cancel();
    // Recordings kept for messages that never sent are no longer needed.
    for (final options in _sendOptions.values) {
      _deleteRecordings(options.media);
    }
    _sendOptions.clear();
  }

  /// Publishes the new immutable state.
  void _set(ChatHistoryState next) => state = next;

  String get _currentUserId => ref.read(authNotifierProvider).user?.id ?? '';

  String get currentUserName {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) return 'You';
    final name = '${user.firstName} ${user.lastName}'.trim();
    return name.isNotEmpty ? name : user.username;
  }

  String? get currentUserAvatarUrl {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) return null;
    return user.avatarUrl.isNotEmpty ? user.avatarUrl : user.defaultAvatarUrl;
  }

  bool isMyMessage(Map<String, dynamic> message) {
    final senderId = message['user_id'] ?? message['userId'];
    return senderId == _currentUserId || senderId == 'me';
  }

  String? get lastSentMessageContent {
    for (final msg in state.messages) {
      if (isMyMessage(msg) && msg['status'] != 'failed') {
        return msg['content'] as String?;
      }
    }
    return null;
  }

  String? get lastSentMessageId {
    for (final msg in state.messages) {
      if (isMyMessage(msg) && msg['status'] != 'failed') {
        return msg['id'] as String?;
      }
    }
    return null;
  }

  Future<void> _loadInitial() async {
    try {
      final repository = ref.read(dmRepositoryProvider);
      final loaded = await repository.getMessages(channelId, page: 1);
      _set(
        state.copyWith(
          messages: loaded,
          hasMore: loaded.length >= DmRepository.pageSize,
          page: 1,
        ),
      );
    } catch (_) {
    } finally {
      _set(state.copyWith(isLoading: false));
    }
    // Start polling for new messages now that the initial load is done.
    _startPolling();
  }

  // ── Realtime notification polling ──────────────────────────────────────────

  void _startPolling() {
    // Record all initially-loaded IDs as "already seen" so we only notify
    // about messages that arrive AFTER the initial load.
    for (final m in state.messages) {
      final id = m['id']?.toString();
      if (id != null) _seenIds.add(id);
    }

    // Poll every 10 seconds for new messages.
    _pollingTimer = Stream<int>.periodic(const Duration(seconds: 10), (i) => i)
        .listen((_) {
          _pollForNewMessages();
        });
  }

  Future<void> _pollForNewMessages() async {
    if (_isHistoryClearedLocally) return;
    try {
      final repository = ref.read(dmRepositoryProvider);
      final fresh = await repository.getMessages(channelId, page: 1);

      bool hadNew = false;
      for (final msg in fresh) {
        final id = msg['id']?.toString();
        if (id == null || _seenIds.contains(id)) continue;

        _seenIds.add(id);
        hadNew = true;

        // Only notify for messages from other users.
        if (!isMyMessage(msg)) {
          final senderName =
              (msg['sender_name'] ?? msg['username'] ?? 'Someone').toString();
          ref
              .read(notificationServiceProvider)
              .handleIncomingMessage(msg, channelId, senderName);
        }
      }

      if (hadNew) {
        // Prepend only the genuinely new messages at the top.
        final existingIds = state.messages
            .map((m) => m['id']?.toString())
            .toSet();
        final newOnly = fresh
            .where(
              (m) =>
                  !existingIds.contains(m['id']?.toString()) && !_isDeleted(m),
            )
            .toList();
        if (newOnly.isNotEmpty) {
          _set(state.copyWith(messages: [...newOnly, ...state.messages]));
        }
      }
    } catch (_) {
      // Silent — polling failures should not surface to the UI.
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    _set(state.copyWith(isLoading: true));

    try {
      final repository = ref.read(dmRepositoryProvider);
      final nextPage = state.page + 1;
      final newMessages = await repository.getMessages(
        channelId,
        page: nextPage,
      );

      _set(
        state.copyWith(
          messages: [
            ...state.messages,
            ...newMessages.where((m) => !_isDeleted(m)),
          ],
          hasMore: newMessages.length >= DmRepository.pageSize,
          page: nextPage,
        ),
      );
    } catch (_) {
    } finally {
      _set(state.copyWith(isLoading: false));
    }
  }

  /// Deletes voice recordings this app made once their message is sent. Files
  /// the user picked are never deleted.
  Future<void> _deleteRecordings(List<XFile>? files) async {
    for (final file in files ?? const <XFile>[]) {
      if (appRecordedPaths.remove(file.path)) {
        try {
          await File(file.path).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> sendMessage(
    String content, {
    List<XFile>? media,
    List<dynamic>? mentions,
    bool isChannel = false,
  }) async {
    _isHistoryClearedLocally = false;
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final currentUserId = _currentUserId;
    final optimisticMessage = {
      "id": tempId,
      "content": content,
      "channel_id": channelId,
      "user_id": currentUserId,
      "userId": currentUserId,
      "type": "user",
      "created_at": DateTime.now().toIso8601String(),
      "status": "sending",
      "is_channel": isChannel,
      if (media != null && media.isNotEmpty)
        "media": [
          for (final file in media) {"file_name": file.name},
        ],
    };

    _sendOptions[tempId] = (media: media, isChannel: isChannel);
    _set(state.copyWith(messages: [optimisticMessage, ...state.messages]));

    try {
      final repository = ref.read(dmRepositoryProvider);
      final threadId = await repository.sendMessage(
        channelId,
        content,
        media: media,
        mentions: mentions,
        isChannel: isChannel,
      );
      _sendOptions.remove(tempId);
      _deleteRecordings(media);

      _set(
        state.copyWith(
          messages: state.messages.map((m) {
            if (m['id'] == tempId) {
              final newMsg = Map<String, dynamic>.from(m);
              newMsg.remove('status');
              newMsg['thread_id'] = threadId;
              return newMsg;
            }
            return m;
          }).toList(),
        ),
      );
    } catch (_) {
      _set(
        state.copyWith(
          messages: state.messages.map((m) {
            if (m['id'] == tempId) {
              final newMsg = Map<String, dynamic>.from(m);
              newMsg['status'] = 'failed';
              return newMsg;
            }
            return m;
          }).toList(),
        ),
      );
    }
  }

  Future<void> retryMessage(String messageId) async {
    final idx = state.messages.indexWhere((m) => m['id'] == messageId);
    if (idx == -1) return;

    final failedMsg = Map<String, dynamic>.from(state.messages[idx]);
    final content = failedMsg['content'] as String? ?? '';

    failedMsg['status'] = 'sending';
    final sending = List<Map<String, dynamic>>.from(state.messages);
    sending[idx] = failedMsg;
    _set(state.copyWith(messages: sending));

    try {
      final repository = ref.read(dmRepositoryProvider);
      final options = _sendOptions[messageId];
      final threadId = await repository.sendMessage(
        channelId,
        content,
        media: options?.media,
        isChannel:
            failedMsg['is_channel'] as bool? ?? options?.isChannel ?? false,
      );
      _sendOptions.remove(messageId);
      _deleteRecordings(options?.media);

      _set(
        state.copyWith(
          messages: state.messages.map((m) {
            if (m['id'] == messageId) {
              final newMsg = Map<String, dynamic>.from(m);
              newMsg.remove('status');
              newMsg['thread_id'] = threadId;
              return newMsg;
            }
            return m;
          }).toList(),
        ),
      );
    } catch (_) {
      _set(
        state.copyWith(
          messages: state.messages.map((m) {
            if (m['id'] == messageId) {
              final newMsg = Map<String, dynamic>.from(m);
              newMsg['status'] = 'failed';
              return newMsg;
            }
            return m;
          }).toList(),
        ),
      );
    }
  }

  void clearLocalHistory() {
    _isHistoryClearedLocally = true;
    _set(state.copyWith(messages: const [], hasMore: false, page: 1));
  }

  void startEditing(String messageId) {
    final msg = state.messages.firstWhere(
      (m) => m['id'] == messageId,
      orElse: () => <String, dynamic>{},
    );
    if (msg.isEmpty) return;

    _set(state.copyWith(editingMessageId: messageId));
  }

  void cancelEditing() {
    _set(state.copyWith(clearEditingMessageId: true));
  }

  bool _isDeleted(Map<String, dynamic> message) =>
      _deletedIds.contains(message['id']?.toString());

  /// Removes the message right away and puts it back if the request fails.
  Future<void> deleteMessage(String messageId) async {
    final index = state.messages.indexWhere((m) => m['id'] == messageId);
    if (index == -1) return;

    final removed = state.messages[index];
    final threadId = (removed['thread_id'] ?? removed['id']).toString();
    _deletedIds.add(messageId);
    _set(
      state.copyWith(
        messages: [...state.messages]..removeAt(index),
        clearEditingMessageId: state.editingMessageId == messageId,
      ),
    );

    try {
      final repository = ref.read(dmRepositoryProvider);
      await repository.deleteMessage(threadId: threadId, channelId: channelId);
    } catch (_) {
      _deletedIds.remove(messageId);
      _set(
        state.copyWith(
          messages: [...state.messages]
            ..insert(index.clamp(0, state.messages.length), removed),
        ),
      );
    }
  }

  Future<void> saveEdit(String messageId, String newContent) {
    final previous = _saveEditChains[messageId] ?? Future<void>.value();
    final task = previous.then((_) => _runSaveEdit(messageId, newContent));
    _saveEditChains[messageId] = task.catchError((_) {});
    return task;
  }

  Future<void> _runSaveEdit(String messageId, String newContent) async {
    if (newContent.trim().isEmpty) {
      cancelEditing();
      return;
    }

    final baselineContent =
        state.messages.firstWhere(
              (m) => m['id'] == messageId,
              orElse: () => <String, dynamic>{},
            )['content']
            as String?;

    _set(
      state.copyWith(
        messages: state.messages.map((m) {
          if (m['id'] == messageId) {
            final updated = Map<String, dynamic>.from(m);
            updated['content'] = newContent;
            return updated;
          }
          return m;
        }).toList(),
        clearEditingMessageId: state.editingMessageId == messageId,
      ),
    );

    try {
      final repository = ref.read(dmRepositoryProvider);
      await repository.editMessage(channelId, content: newContent);
    } catch (_) {
      _set(
        state.copyWith(
          messages: state.messages.map((m) {
            if (m['id'] == messageId && m['content'] == newContent) {
              final reverted = Map<String, dynamic>.from(m);
              reverted['content'] = baselineContent;
              return reverted;
            }
            return m;
          }).toList(),
        ),
      );
    }
  }
}

final chatHistoryProvider =
    NotifierProvider.family<ChatHistoryNotifier, ChatHistoryState, String>(
      ChatHistoryNotifier.new,
    );
