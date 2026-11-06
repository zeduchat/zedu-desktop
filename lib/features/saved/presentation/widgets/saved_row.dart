import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// One saved message. Tapping it opens the conversation it came from.
class SavedRow extends ConsumerWidget {
  const SavedRow({super.key, required this.item, this.reminder, this.now});

  final SavedMessage item;

  /// The pending reminder on this message, when there is one.
  final MessageReminder? reminder;

  /// Injected by tests so "Today" and "Tomorrow" are stable.
  final DateTime? now;

  /// Opens the conversation the saved message belongs to.
  ///
  /// A channel is opened by name and id. A direct message needs the other
  /// participant, which the saved payload does not carry, so it is resolved
  /// from the loaded conversations; when it is not there the user is told
  /// rather than being left with a row that does nothing.
  void _open(BuildContext context, WidgetRef ref) {
    final activeChat = ref.read(activeChatProvider.notifier);
    final sidebar = ref.read(homeSidebarProvider.notifier);
    final channelId = item.target.channelId;

    if (!item.isDirectMessage) {
      final name = item.conversationName;
      if (name == null || name.isEmpty) return;
      activeChat.selectChannel(name, channelId: channelId);
      sidebar.setType(HomeSidebarType.home);
      return;
    }

    if (item.channelType == 'groupDM') {
      activeChat.selectGroupDm(channelId);
      sidebar.setType(HomeSidebarType.dms);
      return;
    }

    final conversations =
        ref.read(dmListProvider).value ?? const <DmConversation>[];
    final match = conversations
        .where(
          (DmConversation conversation) => conversation.channelId == channelId,
        )
        .firstOrNull;

    if (match == null) {
      AppToastService.show(
        context,
        type: AppToastType.info,
        message: 'Open that conversation from Direct messages first.',
      );
      return;
    }

    activeChat.selectDirectMessage(match.participantId);
    sidebar.setType(HomeSidebarType.dms);
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    await handleSavedMenuAction(context, ref, value, item.target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final avatarUrl = item.avatarUrl;
    final remindAt = reminder?.remindAt;
    final due = reminder?.isDue(now ?? DateTime.now()) ?? false;

    return InkWell(
      onTap: () => _open(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      avatarInitial(item.authorName),
                      style: TextStyle(color: colors.onPrimary),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          item.conversationLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (due) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.error,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Due',
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Saved ${formatReminder(context, item.savedAt, now: now)}',
                        style: TextStyle(color: colors.textHint, fontSize: 11),
                      ),
                      if (remindAt != null) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.alarm,
                          size: 12,
                          color: due ? colors.error : colors.textHint,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Reminder: ${formatReminder(context, remindAt, now: now)}',
                          style: TextStyle(
                            color: due ? colors.error : colors.textHint,
                            fontSize: 11,
                            fontWeight: due
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Saved message actions',
              icon: Icon(Icons.more_horiz, size: 18, color: colors.textHint),
              onSelected: (value) => _onMenu(context, ref, value),
              itemBuilder: (_) => [
                const PopupMenuItem<String>(
                  value: SavedMenuAction.unsave,
                  child: Text('Remove from saved'),
                ),
                PopupMenuItem<String>(
                  value: SavedMenuAction.remind,
                  child: Text(
                    reminder == null ? 'Remind me' : 'Change reminder',
                  ),
                ),
                if (reminder != null)
                  const PopupMenuItem<String>(
                    value: SavedMenuAction.clearReminder,
                    child: Text('Cancel reminder'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
