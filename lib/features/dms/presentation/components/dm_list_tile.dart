import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class DmListTile extends ConsumerWidget {
  final DmConversation conversation;

  const DmListTile({super.key, required this.conversation});

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dt.year, dt.month, dt.day);

    if (messageDay == today) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (messageDay == yesterday) {
      return 'Yesterday';
    }

    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selected = ref.watch(selectedDmProvider);
    final activeChat = ref.watch(activeChatProvider);
    final isSelected =
        (selected != null &&
            (selected.channelId == conversation.channelId ||
                (selected.channelId.isEmpty &&
                    selected.participantId == conversation.participantId))) ||
        (activeChat.type == ActiveChatType.directMessage &&
            activeChat.id == conversation.participantId);
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: () {
        ref.read(selectedDmProvider.notifier).select(conversation);
        ref
            .read(activeChatProvider.notifier)
            .selectDirectMessage(conversation.participantId);
      },
      hoverColor: colors.onPrimary.withValues(alpha: 0.08),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.onPrimary.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? colors.accent : Colors.transparent,
              width: 3.5,
            ),
            top: BorderSide(color: colors.onPrimary.withValues(alpha: 0.18)),
            bottom: BorderSide(color: colors.onPrimary.withValues(alpha: 0.18)),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary,
              backgroundImage: conversation.effectiveAvatarUrl != null
                  ? NetworkImage(conversation.effectiveAvatarUrl!)
                  : null,
              child: conversation.effectiveAvatarUrl == null
                  ? Text(
                      conversation.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.displayName,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.previewMessage,
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.86),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(conversation.lastActivityAt),
                  style: TextStyle(
                    color: colors.onPrimary.withValues(alpha: 0.92),
                    fontSize: 11,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
