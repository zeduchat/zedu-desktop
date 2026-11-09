import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Shortens [text] for a notification banner: over 80 characters, it keeps the
/// first 77 and adds "...". It counts characters as people see them (grapheme
/// clusters), so an emoji or accented letter at the cut is never split.
String notificationPreview(String text) {
  // Messages from another client can carry HTML. Strip the markup and decode
  // entities *before* truncating, so the cut never lands inside a tag or an
  // escaped character and the banner shows what the sender wrote.
  final plain = _notificationPlainText(text);
  final characters = plain.characters;
  if (characters.length <= 80) return plain;
  return '${characters.take(77)}...';
}

/// The channel behind [channelId] in [channels], or null when it is not one
/// of them (a DM, for instance).
Channel? channelForNotification(List<Channel> channels, String channelId) {
  for (final channel in channels) {
    if (channel.id == channelId) return channel;
  }
  return null;
}

/// The title of a message notification: a channel message names the channel,
/// a DM names the sender.
String notificationTitle({required String senderName, Channel? channel}) {
  if (channel == null) return 'New DM from $senderName';
  return 'New message in #${channel.name}';
}

/// The body of a message notification. A channel message also says who wrote
/// it, since the title only names the channel.
String notificationBody({
  required String senderName,
  required String preview,
  Channel? channel,
}) {
  if (channel == null) return preview;
  return notificationPreview('$senderName: $preview');
}

/// Whether [channel] is the conversation on screen: the Home pane is showing
/// it. The id of the picked channel wins; the name finds #general at the
/// start, before any channel has been picked.
bool isChannelOpen({
  required ActiveChatState chat,
  required HomeSidebarType sidebar,
  required Channel channel,
}) {
  if (sidebar != HomeSidebarType.home) return false;
  if (chat.type != ActiveChatType.channel) return false;
  final pickedId = chat.channelId;
  if (pickedId != null) return pickedId == channel.id;
  return (chat.id ?? '').toLowerCase() == channel.name.toLowerCase();
}

/// Tags become a space so words on either side do not run together, entities
/// are decoded until decoding no longer changes the text, and the whitespace
/// that leaves behind is collapsed.
String _notificationPlainText(String raw) {
  if (raw.isEmpty) return '';
  var text = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
  };
  for (var i = 0; i < 3; i++) {
    final before = text;
    entities.forEach((k, v) => text = text.replaceAll(k, v));
    if (text == before) break;
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

/// The saved Settings > Notifications preferences for the selected workspace,
/// or null while loading or when they cannot be loaded. Refreshed when the
/// workspace changes or the preferences are saved.
final desktopNotificationPreferencesProvider =
    FutureProvider<NotificationPreferences?>((ref) async {
      final orgId = ref.watch(currentOrgIdProvider);
      final result = await ref
          .watch(userProfileRepositoryProvider)
          .getNotificationPreferences(orgId: orgId.isEmpty ? null : orgId);
      return switch (result) {
        Success<NotificationPreferences>() => result.value,
        Failure<NotificationPreferences>() => null,
      };
    });

class NotificationService {
  final Ref _ref;
  final GoRouter? _router;
  final Future<void> Function()? _bringToFront;
  final Future<bool> Function()? _isFocused;
  final Map<String, DateTime> _lastNotificationTimes = {};

  NotificationService(
    this._ref, [
    this._router,
    this._bringToFront,
    this._isFocused,
  ]);

  static Future<void> _defaultBringToFront() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  static Future<bool> _defaultIsFocused() async {
    try {
      return await windowManager.isFocused();
    } catch (_) {
      return false;
    }
  }

  /// The channels the sidebar has already loaded. The list is never fetched
  /// from here: a message from somewhere that is not in it is a DM.
  List<Channel> _loadedChannels() {
    if (!_ref.exists(channelProvider)) return const <Channel>[];
    return _ref.read(channelProvider).value ?? const <Channel>[];
  }

  Future<void> init() async {
    await localNotifier.setup(
      appName: 'Zedu',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
  }

  /// Handles an incoming message and shows a desktop notification.
  ///
  /// When [forceShow] is `true` the focus-check and per-sender throttle are
  /// skipped so that test / manual notifications always fire.
  Future<void> handleIncomingMessage(
    Map<String, dynamic> message,
    String channelId,
    String senderName, {
    bool forceShow = false,
  }) async {
    final settings = _ref.read(notificationSettingsProvider);
    final authState = _ref.read(authNotifierProvider);
    final currentUserId = authState.user?.id ?? '';

    final senderId = (message['user_id'] ?? message['userId']).toString();
    final channel = channelForNotification(_loadedChannels(), channelId);

    // Never notify about our own messages (unless forced for testing).
    if (!forceShow && (senderId == currentUserId || senderId == 'me')) return;

    if (settings.isDndActive) return;
    if (settings.isMuted(senderId)) return;

    if (!forceShow) {
      final allowed = desktopNotificationAllowed(
        preferences: _ref.read(desktopNotificationPreferencesProvider).value,
        status: authState.user?.status,
        now: DateTime.now(),
      );
      if (!allowed) return;

      final isFocused = await (_isFocused?.call() ?? _defaultIsFocused());
      final selectedChannel = _ref.read(selectedDmProvider)?.channelId;

      if (isFocused && selectedChannel == channelId) {
        return;
      }

      // A channel message is not a DM: skip it while that channel is open.
      if (isFocused &&
          channel != null &&
          isChannelOpen(
            chat: _ref.read(activeChatProvider),
            sidebar: _ref.read(homeSidebarProvider),
            channel: channel,
          )) {
        return;
      }

      final now = DateTime.now();
      final lastTime = _lastNotificationTimes[senderId];
      if (lastTime != null && now.difference(lastTime).inSeconds < 5) {
        return;
      }
      _lastNotificationTimes[senderId] = now;
    }

    String contentPreview = (message['content'] ?? '').toString();
    if (contentPreview.isEmpty) {
      final media = message['media'] as List<dynamic>? ?? [];
      if (media.isNotEmpty) {
        contentPreview = 'Sent an attachment';
      } else {
        contentPreview = 'New message';
      }
    }

    contentPreview = notificationPreview(contentPreview);

    final notification = LocalNotification(
      title: notificationTitle(senderName: senderName, channel: channel),
      body: notificationBody(
        senderName: senderName,
        preview: contentPreview,
        channel: channel,
      ),
    );

    notification.onClick = () => handleNotificationClick(
      channelId: channelId,
      senderName: senderName,
      senderId: senderId,
      contentPreview: contentPreview,
    );

    try {
      await notification.show();
    } catch (_) {}
  }

  /// Handles a user clicking on a desktop notification.
  ///
  /// For a channel message it opens that channel on Home. Otherwise it selects
  /// the DM conversation via [selectedDmProvider], switches the sidebar to
  /// [HomeSidebarType.dms], and navigates to [AppRouter.home] if not already on
  /// the home screen.
  Future<void> handleNotificationClick({
    required String channelId,
    required String senderName,
    required String senderId,
    required String contentPreview,
  }) async {
    await (_bringToFront?.call() ?? _defaultBringToFront());

    final channel = channelForNotification(_loadedChannels(), channelId);
    if (channel != null) {
      _ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.home);
      _ref
          .read(activeChatProvider.notifier)
          .selectChannel(channel.name, channelId: channel.id);
      _goHome();
      return;
    }

    _ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.dms);

    final conversations = _ref.read(dmListProvider).value ?? const [];
    DmConversation? conversation;
    for (final c in conversations) {
      if (c.channelId == channelId) {
        conversation = c;
        break;
      }
    }
    conversation ??= DmConversation(
      channelId: channelId,
      username: senderName,
      participantId: senderId,
      previewMessage: contentPreview,
      unreadCount: 0,
    );

    _ref.read(selectedDmProvider.notifier).select(conversation);

    _goHome();
  }

  void _goHome() {
    final router =
        _router ??
        (locator.isRegistered<GoRouter>()
            ? locator<GoRouter>()
            : AppRouter.router);

    try {
      final location = router.routerDelegate.currentConfiguration.uri;
      if (location.path != AppRouter.home) {
        router.go(AppRouter.home);
      }
    } catch (_) {
      router.go(AppRouter.home);
    }
  }
}
