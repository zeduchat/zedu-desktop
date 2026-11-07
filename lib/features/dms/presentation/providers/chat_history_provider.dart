import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ChatHistoryNotifier extends ChangeNotifier {
  static const _tag = 'ChatHistoryNotifier';

  final String channelId;
  final Ref ref;
  late final ComposerFileStore _fileStore;

  /// Set in dispose(): an asynchronous continuation (polling response, save,
  /// delete or retry) that lands after it must stay a silent no-op instead of
  /// crashing on [notifyListeners] of a disposed notifier.
  bool _isDisposed = false;

  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  bool hasMore = true;
  int page = 1;

  /// Messages created at or before this time were cleared with "Clear
  /// history" and stay hidden.
  DateTime? _clearedAt;

  bool get historyCleared => _clearedAt != null;

  /// Whether the first page of history failed to load.
  bool loadFailed = false;

  /// Whether the last request for older messages failed.
  bool loadMoreFailed = false;

  String? editingMessageId;
  final Map<String, Future<void>> _saveEditChains = {};

  /// Messages whose edit is still being sent. A poll that lands meanwhile must
  /// not put the old text back over the edit.
  final Set<String> _editsInFlight = {};

  /// Messages being sent right now, so a second send of the same message is a
  /// no-op instead of a duplicate.
  final Set<String> _sendsInFlight = {};

  /// What is known about messages that failed to send: how many attempts they
  /// had and when the first one started, which is what lets a retry recognise
  /// a copy that already reached the server.
  final Map<String, OutboundSend> _outboundSends = {};

  /// Automatic retries waiting to run, cancelled when the message gets through
  /// or the conversation closes.
  final Map<String, Timer> _retryTimers = {};

  static const SendRetryPolicy _retryPolicy = SendRetryPolicy();

  ChatHistoryNotifier(this.channelId, this.ref) {
    _fileStore = ref.read(composerFileStoreProvider);
    _loadInitial();
  }

  String get _currentUserId {
    final authState = ref.read(authNotifierProvider);
    return authState.user?.id ?? '';
  }

  /// The signed-in user's id, or '' when signed out.
  String get currentUserId => _currentUserId;

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
    for (final msg in messages) {
      if (isMyMessage(msg) && msg['status'] != 'failed') {
        return msg['content'] as String?;
      }
    }
    return null;
  }

  String? get lastSentMessageId {
    for (final msg in messages) {
      if (isMyMessage(msg) && msg['status'] != 'failed') {
        return msg['id'] as String?;
      }
    }
    return null;
  }

  Future<void> _loadInitial() async {
    await _loadFirstPage();
    if (_isDisposed) return;
    // Start polling for new messages now that the initial load is done.
    _startPolling();
  }

  Future<void> _loadFirstPage() async {
    try {
      _clearedAt = await ref
          .read(dmHistoryClearStoreProvider)
          .clearedAt(channelId);
    } catch (_) {}
    try {
      final repository = ref.read(dmRepositoryProvider);
      final loaded = await repository.getMessages(channelId, page: 1);
      final visible = loaded.where((m) => !_isCleared(m)).toList();
      // Keep messages sent (or failing to send) while the history was missing.
      final unsent = messages.where((m) => m['status'] != null);
      messages = [...unsent, ...visible];
      hasMore =
          loaded.length >= DmRepository.pageSize &&
          visible.length == loaded.length;
      page = 1;
      loadFailed = false;
      _markSeen(loaded);
    } catch (e, st) {
      AppLogger.e(
        'Failed to load initial chat history for channel $channelId',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      loadFailed = true;
    } finally {
      if (!_isDisposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Loads the first page again after it failed.
  Future<void> retryLoad() async {
    if (isLoading) return;
    isLoading = true;
    loadFailed = false;
    notifyListeners();
    await _loadFirstPage();
  }

  // ── Realtime notification polling ────────────────────────────────────────────

  /// Set of message IDs we have already seen. Used to detect truly-new messages
  /// so we don't re-fire a notification on every poll cycle.
  final Set<String> _seenIds = {};

  /// Keep track of the polling timer so we can cancel it on dispose.
  // ignore: cancel_subscriptions
  dynamic _pollingTimer;

  // Record loaded IDs as "already seen" so we only notify about messages that
  // arrive AFTER they were loaded.
  void _markSeen(List<Map<String, dynamic>> loaded) {
    for (final m in loaded) {
      final id = m['id']?.toString();
      if (id != null) _seenIds.add(id);
    }
  }

  void _startPolling() {
    // Poll every 10 seconds for new messages.
    _pollingTimer = Stream<int>.periodic(const Duration(seconds: 10), (i) => i)
        .listen((_) {
          _pollForNewMessages();
        });
  }

  /// True while a poll request is running. A slow response must not be
  /// overlapped by the next tick, or requests pile up (#2656).
  bool _pollInFlight = false;

  Future<void> _pollForNewMessages() async {
    // Until the history loads, every polled message would look new.
    if (loadFailed || _pollInFlight) return;
    if (_isDisposed) return;
    _pollInFlight = true;
    try {
      final repository = ref.read(dmRepositoryProvider);
      final fresh = await repository.getMessages(channelId, page: 1);
      if (_isDisposed) return;

      // A message edited elsewhere keeps its id, so it is not "new": replace
      // its text in place, without a notification or a second copy.
      final changed = _applyEditedContent(fresh);

      bool hadNew = false;
      for (final msg in fresh) {
        final id = msg['id']?.toString();
        if (id == null || _seenIds.contains(id) || _isCleared(msg)) continue;

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
        // A message just sent keeps its local id and stores the server's id as
        // thread_id, so match on both or the poll adds a second copy of it.
        final existingIds = <String?>{
          for (final m in messages) ...[
            m['id']?.toString(),
            if (m['thread_id'] != null) m['thread_id'].toString(),
          ],
        };
        final newOnly = fresh
            .where(
              (m) =>
                  !existingIds.contains(m['id']?.toString()) &&
                  !_isDeleted(m) &&
                  !_isCleared(m),
            )
            .toList();
        if (newOnly.isNotEmpty) {
          messages = [...newOnly, ...messages];
          notifyListeners();
          return;
        }
      }
      if (changed) notifyListeners();
    } catch (_) {
      // Silent — polling failures should not surface to the UI.
    } finally {
      _pollInFlight = false;
    }
  }

  /// Merges the server's current fields onto every loaded message with the
  /// same id. Skips locally pending messages and messages being edited here,
  /// and returns whether anything changed.
  bool _applyEditedContent(List<Map<String, dynamic>> fresh) {
    final latest = <String, Map<String, dynamic>>{
      for (final m in fresh)
        if (m['id'] != null && !_isDeleted(m)) m['id'].toString(): m,
    };
    var changed = false;
    messages = messages.map((m) {
      final id = m['id']?.toString();
      if (id == null || !latest.containsKey(id)) return m;
      if (m['status'] != null ||
          _editsInFlight.contains(id) ||
          editingMessageId == id) {
        return m;
      }
      final updated = Map<String, dynamic>.from(m)..addAll(latest[id]!);
      if (_sameJsonValue(updated, m)) return m;
      changed = true;
      return updated;
    }).toList();
    return changed;
  }

  /// Whether [messageId] is being sent right now.
  bool isSending(String messageId) => _sendsInFlight.contains(messageId);

  /// How long until [messageId] is retried by itself, or null when it will not
  /// be retried again and the person has to choose.
  Duration? retryIn(String messageId) {
    final record = _outboundSends[messageId];
    if (record == null || !_retryPolicy.canRetry(record.attempts)) return null;
    return _retryPolicy.delayBefore(record.attempts + 1);
  }

  /// The newest message on the server that is already a copy of [send].
  ///
  /// Best effort: if the lookup fails the retry still runs, which is exactly
  /// what happened before this check existed.
  Future<Map<String, dynamic>?> _findDeliveredCopy(OutboundSend send) async {
    try {
      final repository = ref.read(dmRepositoryProvider);
      final page = await repository.getMessages(channelId, page: 1);
      if (_isDisposed) return null;
      return findDeliveredCopy(page, send: send, senderId: _currentUserId);
    } catch (_) {
      return null;
    }
  }

  /// Treats [messageId] as sent, using the copy that is already on the server.
  void _markDelivered(String messageId, Map<String, dynamic> delivered) {
    _outboundSends.remove(messageId);
    _cancelRetry(messageId);
    // The attempt that already landed keeps its recording only until now: the
    // message is delivered, so the local copy is no longer needed for a retry.
    _deleteRecordings(_sendOptions.remove(messageId)?.media);
    final threadId = (delivered['thread_id'] ?? delivered['id'])?.toString();
    messages = messages.map((m) {
      if (m['id'] != messageId) return m;
      final updated = Map<String, dynamic>.from(m);
      updated.remove('status');
      if (threadId != null && threadId.isNotEmpty) {
        updated['thread_id'] = threadId;
      }
      return updated;
    }).toList();
    notifyListeners();
  }

  void _scheduleRetry(String messageId) {
    final record = _outboundSends[messageId];
    if (record == null || !_retryPolicy.canRetry(record.attempts)) return;
    _cancelRetry(messageId);
    _retryTimers[messageId] = Timer(
      _retryPolicy.delayBefore(record.attempts + 1),
      () {
        _retryTimers.remove(messageId);
        if (_isDisposed) return;
        unawaited(retryMessage(messageId));
      },
    );
  }

  void _cancelRetry(String messageId) {
    _retryTimers.remove(messageId)?.cancel();
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _sendsInFlight.clear();
    _outboundSends.clear();
    (_pollingTimer as dynamic)?.cancel();
    // Recordings kept for messages that never sent are no longer needed.
    for (final options in _sendOptions.values) {
      _deleteRecordings(options.media);
    }
    _sendOptions.clear();
    super.dispose();
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore || loadFailed) return;

    isLoading = true;
    loadMoreFailed = false;
    notifyListeners();

    try {
      final repository = ref.read(dmRepositoryProvider);
      final nextPage = page + 1;
      final newMessages = await repository.getMessages(
        channelId,
        page: nextPage,
      );

      messages = [
        ...messages,
        ...newMessages.where((m) => !_isDeleted(m) && !_isCleared(m)),
      ];
      // Pages run newest first, so once a cleared message shows up every
      // older page is cleared too.
      hasMore =
          newMessages.length >= DmRepository.pageSize &&
          !newMessages.any(_isCleared);
      page = nextPage;
    } catch (e, st) {
      AppLogger.e(
        'Failed to load more messages for channel $channelId on page ${page + 1}',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      loadMoreFailed = true;
    } finally {
      if (!_isDisposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Loads every remaining page, for views that need the whole conversation
  /// (such as its files). Waits for a load already in flight, and stops after
  /// [maxPages] pages or when a page fails, so it can't loop forever.
  Future<void> loadAll({int maxPages = 50}) async {
    for (var i = 0; i < maxPages && hasMore; i++) {
      while (isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!hasMore) break;
      final before = page;
      await loadMore();
      if (page == before) break; // the page failed to load
    }
  }

  // What each message was sent with, so a retry sends it the same way.
  final Map<
    String,
    ({List<XFile>? media, List<dynamic>? mentions, bool isChannel})
  >
  _sendOptions = {};

  /// Makes each optimistic message id unique, even for sends in the same
  /// millisecond: the id keys [_sendOptions] and the message's later update.
  int _tempIdCounter = 0;

  /// Deletes voice recordings this app made once their message is sent. Files
  /// the user picked are never deleted.
  Future<void> _deleteRecordings(List<XFile>? files) async {
    for (final file in files ?? const <XFile>[]) {
      final result = await _fileStore.deleteRecording(file.path);
      if (result case Failure(:final error)) {
        AppLogger.w(error.message, tag: 'ChatHistoryNotifier');
      }
    }
  }

  Future<void> sendMessage(
    String content, {
    List<XFile>? media,
    List<dynamic>? mentions,
    bool isChannel = false,
  }) async {
    final tempId =
        'local-${DateTime.now().millisecondsSinceEpoch}-${_tempIdCounter++}';
    final optimisticMessage = {
      "id": tempId,
      "content": content,
      "channel_id": channelId,
      "user_id": _currentUserId,
      "userId": _currentUserId,
      "sender_name": currentUserName,
      "avatar_url": currentUserAvatarUrl,
      "type": "user",
      "created_at": DateTime.now().toIso8601String(),
      "status": "sending",
      "is_channel": isChannel,
      if (media != null && media.isNotEmpty)
        "media": [
          for (final file in media) {"file_name": file.name},
        ],
    };

    // The same text must not be in flight twice. A double Enter, or a double
    // click on Send, would otherwise post two messages before either resolves.
    final normalised = normaliseMessageText(content);
    final sameTextInFlight = _outboundSends.entries.any(
      (entry) =>
          _sendsInFlight.contains(entry.key) &&
          normaliseMessageText(entry.value.content) == normalised,
    );
    if (sameTextInFlight) return;

    _sendOptions[tempId] = (
      media: media,
      mentions: mentions,
      isChannel: isChannel,
    );
    _outboundSends[tempId] = OutboundSend.starting(
      clientId: tempId,
      content: content,
      at: DateTime.now(),
    );
    _sendsInFlight.add(tempId);
    messages = [optimisticMessage, ...messages];
    notifyListeners();

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
      _outboundSends.remove(tempId);
      _cancelRetry(tempId);
      _deleteRecordings(media);

      messages = messages.map((m) {
        if (m['id'] == tempId) {
          final newMsg = Map<String, dynamic>.from(m);
          newMsg.remove('status');
          newMsg['thread_id'] = threadId;
          return newMsg;
        }
        return m;
      }).toList();
    } catch (e, st) {
      AppLogger.e(
        'Failed to send message in channel $channelId',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      if (_isDisposed) return;
      messages = messages.map((m) {
        if (m['id'] == tempId) {
          final newMsg = Map<String, dynamic>.from(m);
          newMsg['status'] = 'failed';
          return newMsg;
        }
        return m;
      }).toList();
      // Try again by itself, within the policy's attempt budget.
      _scheduleRetry(tempId);
    } finally {
      _sendsInFlight.remove(tempId);
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> retryMessage(String messageId) async {
    // A message already being sent cannot be sent again: a second tap on
    // Retry would otherwise post it twice. The slot is taken before the first
    // await, because the delivered-copy lookup below is itself asynchronous
    // and a second tap during it would otherwise start a second request.
    if (!_sendsInFlight.add(messageId)) return;
    try {
      await _retryMessageNow(messageId);
    } finally {
      _sendsInFlight.remove(messageId);
    }
  }

  Future<void> _retryMessageNow(String messageId) async {
    _cancelRetry(messageId);

    final idx = messages.indexWhere((m) => m['id'] == messageId);
    // Status changes to sending synchronously below, so repeated callbacks
    // cannot start another request for this message before the view rebuilds.
    if (idx == -1 || messages[idx]['status'] != 'failed') return;

    final failedMsg = Map<String, dynamic>.from(messages[idx]);
    final content = failedMsg['content'] as String? ?? '';

    // An earlier attempt may have been committed even though the client saw a
    // failure (a response timeout, for example). Adopt that copy instead of
    // sending a second one.
    final record = _outboundSends[messageId];
    if (record != null && record.hasBeenAttempted) {
      final delivered = await _findDeliveredCopy(record);
      if (_isDisposed) return;
      if (delivered != null) {
        _markDelivered(messageId, delivered);
        return;
      }
    }

    final now = DateTime.now();
    _outboundSends[messageId] = record == null
        ? OutboundSend.starting(clientId: messageId, content: content, at: now)
        : record.withAnotherAttempt(now);

    failedMsg['status'] = 'sending';
    messages = List<Map<String, dynamic>>.from(messages);
    messages[idx] = failedMsg;
    notifyListeners();

    try {
      final repository = ref.read(dmRepositoryProvider);
      final options = _sendOptions[messageId];
      final threadId = await repository.sendMessage(
        channelId,
        content,
        media: options?.media,
        mentions: options?.mentions,
        isChannel:
            failedMsg['is_channel'] as bool? ?? options?.isChannel ?? false,
      );
      _sendOptions.remove(messageId);
      _outboundSends.remove(messageId);
      _cancelRetry(messageId);
      _deleteRecordings(options?.media);

      messages = messages.map((m) {
        if (m['id'] == messageId) {
          final newMsg = Map<String, dynamic>.from(m);
          newMsg.remove('status');
          newMsg['thread_id'] = threadId;
          return newMsg;
        }
        return m;
      }).toList();
    } catch (e, st) {
      AppLogger.e(
        'Failed to retry message $messageId in channel $channelId',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      if (_isDisposed) return;
      messages = messages.map((m) {
        if (m['id'] == messageId) {
          final newMsg = Map<String, dynamic>.from(m);
          newMsg['status'] = 'failed';
          return newMsg;
        }
        return m;
      }).toList();
      _scheduleRetry(messageId);
    } finally {
      if (!_isDisposed) notifyListeners();
    }
  }

  static DateTime? _createdAt(Map<String, dynamic> message) =>
      DateTime.tryParse(message['created_at']?.toString() ?? '');

  bool _isCleared(Map<String, dynamic> message) {
    final clearedAt = _clearedAt;
    if (clearedAt == null) return false;
    final createdAt = _createdAt(message);
    return createdAt != null && !createdAt.isAfter(clearedAt);
  }

  /// Hides every message up to now in this conversation, on this device, and
  /// remembers it so they stay hidden after the DM is reopened.
  Future<void> clearLocalHistory() async {
    // Cut off at the newest loaded message rather than this device's clock,
    // so a clock running ahead can't hide messages sent after the clear.
    DateTime? newest;
    for (final message in messages) {
      final createdAt = _createdAt(message);
      if (createdAt != null && (newest == null || createdAt.isAfter(newest))) {
        newest = createdAt;
      }
    }
    final clearedAt = newest ?? DateTime.now();
    _clearedAt = clearedAt;
    messages = [];
    hasMore = false;
    page = 1;
    notifyListeners();

    try {
      await ref
          .read(dmHistoryClearStoreProvider)
          .markCleared(channelId, clearedAt);
    } catch (_) {
      // The messages stay hidden for this session even if saving fails.
    }
  }

  void startEditing(String messageId) {
    final msg = messages.firstWhere(
      (m) => m['id'] == messageId,
      orElse: () => <String, dynamic>{},
    );
    if (msg.isEmpty) return;

    editingMessageId = messageId;
    notifyListeners();
  }

  void cancelEditing() {
    editingMessageId = null;
    notifyListeners();
  }

  /// Ids of messages being deleted or already deleted, so polling and paging
  /// do not bring them back.
  final Set<String> _deletedIds = {};

  bool _isDeleted(Map<String, dynamic> message) =>
      _deletedIds.contains(message['id']?.toString());

  /// Removes the message right away and puts it back if the request fails.
  Future<void> deleteMessage(String messageId) async {
    final index = messages.indexWhere((m) => m['id'] == messageId);
    if (index == -1) return;

    final removed = messages[index];
    final threadId = (removed['thread_id'] ?? removed['id']).toString();
    if (editingMessageId == messageId) editingMessageId = null;
    _deletedIds.add(messageId);
    messages = [...messages]..removeAt(index);
    notifyListeners();

    try {
      final repository = ref.read(dmRepositoryProvider);
      await repository.deleteMessage(threadId: threadId, channelId: channelId);
    } catch (_) {
      if (_isDisposed) return;
      _deletedIds.remove(messageId);
      messages = [...messages]
        ..insert(index.clamp(0, messages.length), removed);
      notifyListeners();
    }
  }

  /// Pins the message on the server. Returns whether it was pinned.
  Future<bool> pinMessage(String messageId) async {
    final message = messages.firstWhere(
      (m) => m['id'] == messageId,
      orElse: () => const {},
    );
    if (message.isEmpty) return false;
    final threadId = (message['thread_id'] ?? message['id']).toString();
    try {
      await ref
          .read(dmRepositoryProvider)
          .pinMessage(threadId: threadId, channelId: channelId);
      return true;
    } catch (_) {
      return false;
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

    final original = messages.firstWhere(
      (m) => m['id'] == messageId,
      orElse: () => <String, dynamic>{},
    );
    final baselineContent = original['content'] as String?;
    // The backend requires thread_id to know which message is being edited.
    final threadId = (original['thread_id'] ?? original['id'])?.toString();

    messages = messages.map((m) {
      if (m['id'] == messageId) {
        final updated = Map<String, dynamic>.from(m);
        updated['content'] = newContent;
        return updated;
      }
      return m;
    }).toList();
    if (editingMessageId == messageId) {
      editingMessageId = null;
    }
    notifyListeners();

    _editsInFlight.add(messageId);
    try {
      final repository = ref.read(dmRepositoryProvider);
      await repository.editMessage(
        messageId,
        content: newContent,
        threadId: threadId,
      );
    } catch (e, st) {
      AppLogger.e(
        'Failed to save edit for message $messageId in channel $channelId',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      if (_isDisposed) return;
      messages = messages.map((m) {
        if (m['id'] == messageId && m['content'] == newContent) {
          final reverted = Map<String, dynamic>.from(m);
          reverted['content'] = baselineContent;
          return reverted;
        }
        return m;
      }).toList();
      notifyListeners();
    } finally {
      _editsInFlight.remove(messageId);
    }
  }
}

final chatHistoryProvider = ChangeNotifierProvider.autoDispose
    .family<ChatHistoryNotifier, String>(
      (ref, channelId) => ChatHistoryNotifier(channelId, ref),
    );

// Polling payloads contain nested maps and arrays. Map identity must not turn
// an unchanged server response into a chat refresh.
bool _sameJsonValue(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) =>
              right.containsKey(key) && _sameJsonValue(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_sameJsonValue(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}
