import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The workspace's channels in the home sidebar. Tapping a row opens it.
class SidebarChannelList extends ConsumerWidget {
  const SidebarChannelList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelState = ref.watch(channelProvider);
    final orgId = ref.watch(
      workspaceProvider.select((s) => s.selectedWorkspace?.id),
    );
    // Right after a workspace switch, and when the new workspace's load
    // failed, the state still holds the previous workspace's channels. Show
    // only channels of the selected workspace, and none after a failed load.
    // A channel without an organisation id is kept, since we can't tell.
    final channels =
        (channelState.hasError
                ? const <Channel>[]
                : channelState.value ?? const <Channel>[])
            .where(
              (c) =>
                  !c.archived &&
                  c.hasAccess &&
                  (c.organisationId.isEmpty || c.organisationId == orgId),
            )
            .toList();
    final activeChat = ref.watch(activeChatProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          for (final channel in channels)
            _SidebarChannelItem(
              label: channel.name,
              unreadCount: channel.unreadCount,
              selected:
                  activeChat.type == ActiveChatType.channel &&
                  (activeChat.channelId == channel.id ||
                      (activeChat.channelId == null &&
                          activeChat.id == channel.name)),
              onTap: () => ref
                  .read(activeChatProvider.notifier)
                  .selectChannel(channel.name, channelId: channel.id),
              onSecondaryTap: (position) =>
                  showChannelRowMenu(context, ref, channel, position),
            ),
        ],
      ),
    );
  }
}

class _SidebarChannelItem extends StatelessWidget {
  final String label;
  final int unreadCount;
  final bool selected;
  final VoidCallback onTap;

  /// Called with the global position of a right-click on the row.
  final ValueChanged<Offset> onSecondaryTap;

  const _SidebarChannelItem({
    required this.label,
    required this.unreadCount,
    required this.selected,
    required this.onTap,
    required this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(6);
    // The open channel is being read, so it never shows a badge.
    final hasUnread = unreadCount > 0 && !selected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? colors.onPrimary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: borderRadius,
        ),
        child: InkWell(
          borderRadius: borderRadius,
          hoverColor: colors.onPrimary.withValues(alpha: 0.06),
          onTap: onTap,
          onSecondaryTapUp: (details) => onSecondaryTap(details.globalPosition),
          child: Stack(
            children: [
              if (selected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      '#',
                      style: TextStyle(
                        color: selected
                            ? colors.accent
                            : colors.onPrimary.withValues(alpha: 0.54),
                        fontSize: 18,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 15,
                          fontWeight: selected || hasUnread
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(width: 8),
                      Container(
                        key: const Key('sidebar-channel-unread-badge'),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount.unreadBadgeText,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
