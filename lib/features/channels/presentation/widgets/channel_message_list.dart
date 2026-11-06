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
            media: ChannelMessage.mediaFrom(m['media'] ?? m['files']),
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
    // Read only when a message names its sender, so lists without sender ids
    // never touch the signed-in user.
    String? me;
    bool isMine(ChannelMessage message) {
      final sender = message.userId;
      if (sender == null || message.threadId == null) return false;
      if (message.status != null) return false;
      me ??= ref.read(chatHistoryProvider(channelId)).currentUserId;
      return me!.isNotEmpty && sender == me;
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        // Only the sender's own, already sent messages can be changed.
        final own = isMine(message);
        final tile = ChannelMessageTile(
          message: message,
          onRetry: message.id != null
              ? () => ref
                    .read(chatHistoryProvider(channelId))
                    .retryMessage(message.id!)
              : null,
          onEdit: own
              ? () => _editChannelMessage(context, ref, channelId, message)
              : null,
          onDelete: own
              ? () => _deleteChannelMessage(context, ref, channelId, message)
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

class ChannelMessageTile extends StatelessWidget {
  const ChannelMessageTile({
    super.key,
    required this.message,
    this.onRetry,
    this.onEdit,
    this.onDelete,
  });

  final ChannelMessage message;
  final VoidCallback? onRetry;

  /// Set for the current user's own messages; shows Edit in the menu.
  final VoidCallback? onEdit;

  /// Set for the current user's own messages; shows Delete in the menu.
  final VoidCallback? onDelete;

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(
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
                    ),
                    if (onEdit != null || onDelete != null)
                      _OwnMessageMenu(onEdit: onEdit, onDelete: onDelete),
                  ],
                ),
                const SizedBox(height: 4),
                if (message.text.isNotEmpty || message.media.isEmpty)
                  ReportMessageMenu(
                    senderName: message.senderName,
                    messageText: message.text,
                    child: MessageLinkScope(
                      builder: (context, links) => SelectableText.rich(
                        buildInlineMarkdownSpan(
                          message.text,
                          TextStyle(fontSize: 15, color: colors.textPrimary),
                          plainText: links.span,
                        ),
                      ),
                    ),
                  ),
                if (message.media.isNotEmpty) ...[
                  if (message.text.isNotEmpty) const SizedBox(height: 8),
                  MessageAttachmentList(media: message.media, isMe: false),
                ],
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

/// Asks for the new text of [message] and saves it (Ziki #2839).
Future<void> _editChannelMessage(
  BuildContext context,
  WidgetRef ref,
  String channelId,
  ChannelMessage message,
) async {
  final threadId = message.threadId;
  if (threadId == null) return;
  final edited = await showDialog<String>(
    context: context,
    builder: (_) => _EditChannelMessageDialog(initialText: message.text),
  );
  if (!context.mounted || edited == null) return;
  final text = edited.trim();
  if (text.isEmpty || text == message.text) return;
  final result = await ref
      .read(channelRepositoryProvider)
      .editChannelMessage(
        channelId: channelId,
        threadId: threadId,
        content: text,
      );
  if (!context.mounted) return;
  switch (result) {
    case Success():
      ref.invalidate(channelHistoryProvider(channelId));
    case Failure():
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: "Couldn't edit the message. Please try again.",
      );
  }
}

/// Confirms, then deletes [message] for everyone (Ziki #2839).
Future<void> _deleteChannelMessage(
  BuildContext context,
  WidgetRef ref,
  String channelId,
  ChannelMessage message,
) async {
  final threadId = message.threadId;
  if (threadId == null) return;
  final colors = context.colors;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete message?'),
      content: const Text('It will be removed for everyone in the channel.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: colors.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) return;
  final result = await ref
      .read(channelRepositoryProvider)
      .deleteChannelMessage(channelId: channelId, threadId: threadId);
  if (!context.mounted) return;
  switch (result) {
    case Success():
      ref.invalidate(channelHistoryProvider(channelId));
    case Failure():
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: "Couldn't delete the message. Please try again.",
      );
  }
}

/// Edit and Delete for the current user's own channel message.
class _OwnMessageMenu extends StatelessWidget {
  const _OwnMessageMenu({this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 28,
      height: 20,
      child: PopupMenuButton<String>(
        key: const ValueKey('channel-message-actions'),
        tooltip: 'Message actions',
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(Icons.more_horiz, color: colors.textSecondary),
        onSelected: (value) {
          if (value == 'edit') onEdit?.call();
          if (value == 'delete') onDelete?.call();
        },
        itemBuilder: (_) => [
          if (onEdit != null)
            const PopupMenuItem(value: 'edit', child: Text('Edit message')),
          if (onDelete != null)
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete message',
                style: TextStyle(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// A menu button to report a message, wrapping the message's [child].
class ReportMessageMenu extends StatelessWidget {
  const ReportMessageMenu({
    super.key,
    required this.senderName,
    required this.messageText,
    required this.child,
  });

  final String senderName;
  final String messageText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: child),
        PopupMenuButton<String>(
          tooltip: 'Report message',
          iconSize: 18,
          icon: const Icon(Icons.flag, size: 18),
          onSelected: (value) {
            if (value == 'report') {
              // TODO: Implement message reporting
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'report', child: Text('Report message')),
          ],
        ),
      ],
    );
  }
}

/// Edits a channel message's text; pops the new text, or null on Cancel.
class _EditChannelMessageDialog extends StatefulWidget {
  const _EditChannelMessageDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditChannelMessageDialog> createState() =>
      _EditChannelMessageDialogState();
}

class _EditChannelMessageDialogState extends State<_EditChannelMessageDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit message'),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const ValueKey('channel-message-edit-field'),
          controller: _controller,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text),
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}
