import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Polls ALL DM conversations for new messages, not just open ones,
/// so desktop notifications fire even for conversations you haven't opened.
///
/// The per-chat poller in [ChatHistoryNotifier] only runs while a DM is open.
/// This notifier polls every conversation on the list, so a new message in an
/// unopened DM still triggers a desktop notification via
/// [notificationServiceProvider.handleIncomingMessage].
class DmNotificationPollerNotifier extends Notifier<void> {
  /// Seen message IDs per channel, so we don't re-fire a notification on every
  /// poll cycle. A channel has no entry until its first poll, which records the
  /// existing messages without notifying so old history never pops up.
  final Map<String, Set<String>> _seenIds = {};

  /// Active per-conversation poll timers.
  final Map<String, StreamSubscription<void>> _pollingTimers = {};

  @override
  void build() {
    ref.onDispose(() {
      for (final channelId in _pollingTimers.keys.toList()) {
        _stopPoller(channelId);
      }
    });

    // Start/stop per-conversation pollers whenever the DM list changes.
    ref.listen(dmListProvider, (previous, next) {
      next.whenData((conversations) {
        _syncConversationPollers(conversations);
      });
    });

    // Kick off polling for conversations already in the list.
    final list = ref.read(dmListProvider);
    list.whenData((conversations) {
      _syncConversationPollers(conversations);
    });
  }

  void _syncConversationPollers(List<DmConversation> conversations) {
    final activeIds = <String>{};
    for (final c in conversations) {
      activeIds.add(c.channelId);
      if (!_pollingTimers.containsKey(c.channelId)) {
        _startPoller(c.channelId);
      }
    }
    for (final channelId in _pollingTimers.keys.toList()) {
      if (!activeIds.contains(channelId)) {
        _stopPoller(channelId);
      }
    }
  }

  void _startPoller(String channelId) {
    _pollingTimers[channelId] =
        Stream<int>.periodic(const Duration(seconds: 10), (i) => i).listen((_) {
          unawaited(_checkForNewMessages(channelId));
        });
  }

  void _stopPoller(String channelId) {
    _pollingTimers[channelId]?.cancel();
    _pollingTimers.remove(channelId);
    _seenIds.remove(channelId);
  }

  Future<void> _checkForNewMessages(String channelId) async {
    try {
      final repository = ref.read(dmRepositoryProvider);
      final fresh = await repository.getMessages(channelId, page: 1);

      // The poller may have been stopped while the request was in flight.
      if (!_pollingTimers.containsKey(channelId)) return;

      final seen = _seenIds[channelId];
      if (seen == null) {
        // First poll: everything returned is history the user already has.
        _seenIds[channelId] = fresh
            .map((msg) => msg['id']?.toString())
            .whereType<String>()
            .toSet();
        return;
      }

      for (final msg in fresh) {
        final id = msg['id']?.toString();
        if (id == null || seen.contains(id)) continue;

        seen.add(id);

        // Only notify for messages from other users.
        final authState = ref.read(authNotifierProvider);
        final currentUserId = authState.user?.id ?? '';
        final senderId = (msg['user_id'] ?? msg['userId']).toString();
        if (senderId == currentUserId || senderId == 'me') continue;

        final senderName = (msg['sender_name'] ?? msg['username'] ?? 'Someone')
            .toString();
        ref
            .read(notificationServiceProvider)
            .handleIncomingMessage(msg, channelId, senderName);
      }
    } catch (_) {
      // Silent — polling failures should not surface to the UI.
    }
  }
}

final dmNotificationPollerProvider =
    NotifierProvider<DmNotificationPollerNotifier, void>(
      DmNotificationPollerNotifier.new,
    );
