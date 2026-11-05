import 'dart:math' as math;

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The messages of a channel, newest at the bottom. Shows [empty] when the
/// channel has no messages yet.
///
/// [unreadCount] is how many messages were unread when the channel was opened
/// (opening it marks it read, so it is remembered here once). A divider marks
/// where they start, and when there are [manyUnread] or more a "Jump to first
/// unread" button scrolls to that point.
class ChannelMessageList extends ConsumerStatefulWidget {
  const ChannelMessageList({
    super.key,
    required this.channelId,
    required this.empty,
    this.unreadCount = 0,
  });

  final String channelId;
  final Widget empty;
  final int unreadCount;

  /// From this many unread messages on, the jump button is offered.
  static const manyUnread = 10;

  @override
  ConsumerState<ChannelMessageList> createState() => _ChannelMessageListState();
}

class _ChannelMessageListState extends ConsumerState<ChannelMessageList> {
  late final int _unreadAtOpen = widget.unreadCount;
  final _firstUnreadKey = GlobalKey();
  final _scroll = ScrollController();
  bool _jumped = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get channelId => widget.channelId;

  @override
  Widget build(BuildContext context) {
    final chatHistory = ref.watch(chatHistoryProvider(channelId));
    final pendingMessages = chatHistory.messages
        .where(
          (m) =>
              m['status'] != null &&
              (m['channel_id'] == channelId || m['is_channel'] == true),
        )
        .map(
          (m) => ChannelMessage(
            id: m['id']?.toString(),
            senderName: (m['sender_name'] as String?)?.isNotEmpty == true
                ? m['sender_name'] as String
                : chatHistory.currentUserName,
            avatarUrl: (m['avatar_url'] as String?)?.isNotEmpty == true
                ? m['avatar_url'] as String
                : chatHistory.currentUserAvatarUrl,
            text: m['content']?.toString() ?? '',
            createdAt: DateTime.tryParse(
              m['created_at']?.toString() ?? '',
            )?.toLocal(),
            status: m['status']?.toString(),
          ),
        )
        .toList();

    return ref
        .watch(channelHistoryProvider(channelId))
        .when(
          loading: () => pendingMessages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _buildList(context, pendingMessages, 0),
          error: (_, _) => pendingMessages.isEmpty
              ? Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(channelHistoryProvider(channelId)),
                    child: const Text("Couldn't load messages. Retry"),
                  ),
                )
              : _buildList(context, pendingMessages, 0),
          data: (serverMessages) {
            final allMessages = [...pendingMessages, ...serverMessages];
            return allMessages.isEmpty
                ? widget.empty
                : _buildList(
                    context,
                    allMessages,
                    // Unread messages are the newest of the server's, so they
                    // sit right after the messages still being sent.
                    pendingMessages.length,
                    serverCount: serverMessages.length,
                  );
          },
        );
  }

  /// Where the unread run starts in [messages] (newest first), or null when
  /// there is nothing to mark. When more messages are unread than were loaded,
  /// the start is not on screen, so the oldest loaded one is used.
  int? _firstUnreadIndex(int offset, int serverCount) {
    if (_unreadAtOpen <= 0 || serverCount == 0) return null;
    final unread = _unreadAtOpen < serverCount ? _unreadAtOpen : serverCount;
    return offset + unread - 1;
  }

  /// Scrolls to the first unread message. It may be far from what is built,
  /// so this steps toward the older messages until it exists, then centres it.
  Future<void> _jump() async {
    setState(() => _jumped = true);
    for (var i = 0; i < 100 && _firstUnreadKey.currentContext == null; i++) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent) break;
      _scroll.jumpTo(
        math.min(
          position.pixels + position.viewportDimension,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final target = _firstUnreadKey.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildList(
    BuildContext context,
    List<ChannelMessage> messages,
    int pendingCount, {
    int serverCount = 0,
  }) {
    final firstUnread = _firstUnreadIndex(pendingCount, serverCount);
    final offerJump =
        firstUnread != null &&
        !_jumped &&
        _unreadAtOpen >= ChannelMessageList.manyUnread;

    final list = ListView.builder(
      reverse: true,
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final tile = ChannelMessageTile(
          message: message,
          onRetry: message.id != null
              ? () => ref
                    .read(chatHistoryProvider(channelId))
                    .retryMessage(message.id!)
              : null,
        );
        if (index != firstUnread) return tile;
        return Column(
          key: _firstUnreadKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [const _UnreadDivider(), tile],
        );
      },
    );

    // Always a Stack, so hiding the button never rebuilds the list underneath.
    return Stack(
      fit: StackFit.expand,
      children: [
        list,
        if (offerJump)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton.tonalIcon(
                key: const ValueKey('jump-to-first-unread'),
                onPressed: _jump,
                icon: const Icon(Icons.arrow_upward, size: 16),
                label: Text('Jump to first unread · $_unreadAtOpen new'),
              ),
            ),
          ),
      ],
    );
  }
}

/// The line shown above the first message that was unread when the channel
/// was opened.
class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: colors.error)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'New messages',
              style: TextStyle(
                color: colors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: colors.error)),
        ],
      ),
    );
  }
}

class ChannelMessageTile extends StatelessWidget {
  const ChannelMessageTile({super.key, required this.message, this.onRetry});

  final ChannelMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final avatarUrl = message.avatarUrl;
    final time = message.createdAt;
    final initial = avatarInitial(message.senderName);
    final status = message.status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.primary,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(initial, style: TextStyle(color: colors.onPrimary))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: message.senderName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                    children: [
                      if (time != null)
                        TextSpan(
                          text:
                              '  ${TimeOfDay.fromDateTime(time).format(context)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                ReportMessageMenu(
                  senderName: message.senderName,
                  messageText: message.text,
                  child: MessageLinkScope(
                    builder: (context, links) => SelectableText.rich(
                      links.span(
                        message.text,
                        TextStyle(fontSize: 15, color: colors.textPrimary),
                      ),
                    ),
                  ),
                ),
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: status == 'failed'
                        ? GestureDetector(
                            onTap: onRetry,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 13,
                                  color: colors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Failed – Tap to retry',
                                  style: TextStyle(
                                    color: colors.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            status == 'sending' ? 'Sending...' : '',
                            style: TextStyle(
                              color: colors.textHint,
                              fontSize: 11,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
