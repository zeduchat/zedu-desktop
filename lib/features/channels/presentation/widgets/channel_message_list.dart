import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The messages of a channel, newest at the bottom. Shows [empty] when the
/// channel has no messages yet.
class ChannelMessageList extends ConsumerWidget {
  const ChannelMessageList({
    super.key,
    required this.channelId,
    required this.empty,
  });

  final String channelId;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              : _buildList(context, ref, pendingMessages),
          error: (_, _) => pendingMessages.isEmpty
              ? Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(channelHistoryProvider(channelId)),
                    child: const Text("Couldn't load messages. Retry"),
                  ),
                )
              : _buildList(context, ref, pendingMessages),
          data: (serverMessages) {
            final allMessages = [...pendingMessages, ...serverMessages];
            return allMessages.isEmpty
                ? empty
                : _buildList(context, ref, allMessages);
          },
        );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<ChannelMessage> messages,
  ) {
    return ListView.builder(
      reverse: true,
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
        // Newest first, so the next index is the older neighbour. A day
        // starts at the oldest message or where the older one is another day.
        final time = message.createdAt;
        final isOldest = index == messages.length - 1;
        final olderTime = isOldest ? null : messages[index + 1].createdAt;
        final startsDay =
            time != null &&
            (isOldest ||
                (olderTime != null && !DateUtils.isSameDay(time, olderTime)));
        if (!startsDay) return tile;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ChannelDayDivider(label: channelDayLabel(time)),
            tile,
          ],
        );
      },
    );
  }
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The label of the divider above a day's first message: "Today",
/// "Yesterday", the weekday within the last week, otherwise the date, with
/// the year only when it isn't this year.
String channelDayLabel(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  // Whole days between the calendar dates, unaffected by DST changes.
  final daysAgo = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  if (daysAgo == 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  final weekday = _weekdays[day.weekday - 1];
  if (daysAgo > 1 && daysAgo < 7) return weekday;
  final date = '$weekday, ${_months[day.month - 1]} ${day.day}';
  return day.year == today.year ? date : '$date, ${day.year}';
}

/// A line with the day's label, above the first message of each day.
class ChannelDayDivider extends StatelessWidget {
  const ChannelDayDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(child: Divider(color: colors.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
            Expanded(child: Divider(color: colors.divider)),
          ],
        ),
      ),
    );
  }
}

/// The text of a channel message as people read it, without the Markdown
/// marks, for "Copy text".
String channelMessagePlainText(String text) =>
    buildInlineMarkdownSpan(text, const TextStyle()).toPlainText();

/// Copies [message]'s plain text and confirms it with a short toast.
Future<void> copyChannelMessageText(
  BuildContext context,
  ChannelMessage message,
) async {
  final text = channelMessagePlainText(message.text);
  if (text.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  AppToastService.show(context, type: AppToastType.success, message: 'Copied');
}

class ChannelMessageTile extends StatefulWidget {
  const ChannelMessageTile({super.key, required this.message, this.onRetry});

  final ChannelMessage message;
  final VoidCallback? onRetry;

  @override
  State<ChannelMessageTile> createState() => _ChannelMessageTileState();
}

class _ChannelMessageTileState extends State<ChannelMessageTile> {
  bool _hovered = false;

  ChannelMessage get message => widget.message;

  /// Opens the message menu with "Copy text" at [position] (global). [anchor]
  /// only places the menu: the hover button that opened it goes away once the
  /// pointer moves onto the menu, so the copy runs on the tile's own context.
  Future<void> _openMenu(BuildContext anchor, Offset position) async {
    final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
    final choice = await showMenu<String>(
      context: anchor,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem<String>(value: 'copy', child: Text('Copy text')),
      ],
    );
    if (choice == 'copy' && mounted) {
      await copyChannelMessageText(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final avatarUrl = message.avatarUrl;
    final time = message.createdAt;
    final initial = avatarInitial(message.senderName);
    final status = message.status;
    final onRetry = widget.onRetry;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (details) =>
            _openMenu(context, details.globalPosition),
        child: Stack(
          children: [
            _buildBody(
              context,
              colors,
              avatarUrl,
              time,
              initial,
              status,
              onRetry,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Visibility(
                visible: _hovered,
                child: Builder(
                  builder: (buttonContext) => IconButton(
                    tooltip: 'Message actions',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.more_horiz, color: colors.textSecondary),
                    onPressed: () {
                      final box = buttonContext.findRenderObject() as RenderBox;
                      _openMenu(
                        buttonContext,
                        box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppPalette colors,
    String? avatarUrl,
    DateTime? time,
    String initial,
    String? status,
    VoidCallback? onRetry,
  ) {
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
                MessageLinkScope(
                  builder: (context, links) => SelectableText.rich(
                    // Right-clicking the text opens the text's own menu, not
                    // the tile's, so "Copy text" has to be added to it.
                    contextMenuBuilder: (context, editableTextState) =>
                        AdaptiveTextSelectionToolbar.buttonItems(
                          anchors: editableTextState.contextMenuAnchors,
                          buttonItems: [
                            ContextMenuButtonItem(
                              label: 'Copy text',
                              onPressed: () {
                                editableTextState.hideToolbar();
                                copyChannelMessageText(this.context, message);
                              },
                            ),
                            ...editableTextState.contextMenuButtonItems,
                          ],
                        ),
                    buildInlineMarkdownSpan(
                      message.text,
                      TextStyle(fontSize: 15, color: colors.textPrimary),
                      plainText: links.span,
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
