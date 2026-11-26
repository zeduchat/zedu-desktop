import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Hover preview shown next to the notifications bell in the sidebar rail.
///
/// Shows the [maxItems] most recently active unread DMs, the same source the
/// full [NotificationsDialog] lists, plus a link that opens that panel.
class NotificationPreviewPopover extends ConsumerWidget {
  const NotificationPreviewPopover({
    super.key,
    required this.onOpenConversation,
    required this.onViewAll,
  });

  static const int maxItems = 3;
  static const double width = 300;

  final ValueChanged<DmConversation> onOpenConversation;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final dmState = ref.watch(dmListProvider);
    final deletedIds = ref.watch(
      dmConversationActionsProvider.select((a) => a.deletedIds),
    );
    final unread =
        (dmState.value ?? const <DmConversation>[])
            .where(
              (c) => c.unreadCount > 0 && !deletedIds.contains(c.channelId),
            )
            .toList()
          ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    final recent = unread.take(maxItems).toList();

    return Material(
      key: const Key('notification-preview-popover'),
      color: colors.background,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Text(
                'Notifications',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Divider(height: 1, color: colors.divider),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Text(
                  "You're all caught up",
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final conversation in recent)
                      UnreadDmRow(
                        conversation: conversation,
                        onTap: () => onOpenConversation(conversation),
                      ),
                  ],
                ),
              ),
            Divider(height: 1, color: colors.divider),
            InkWell(
              onTap: onViewAll,
              mouseCursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'View all notifications',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
