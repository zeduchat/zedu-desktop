import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The Direct messages section of the Home sidebar: a heading with a compose
/// button, then the user's own space as "[Name] (you)", then their other
/// conversations in the same order as the DMs tab. Selecting one opens it in
/// the DMs tab.
class SidebarDmSection extends ConsumerWidget {
  const SidebarDmSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Icon(Icons.arrow_drop_down, color: colors.onPrimary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Direct messages',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              // Opens the same new-message flow as the compose button in
              // the workspace header.
              IconButton(
                tooltip: 'New message',
                onPressed: () {
                  ref.read(selectedDmProvider.notifier).select(null);
                  ref.read(activeChatProvider.notifier).selectNewGroupChat();
                },
                icon: Icon(
                  Icons.edit_note,
                  semanticLabel: 'New message',
                  color: colors.onPrimary.withValues(alpha: 0.7),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const SidebarDmList(),
      ],
    );
  }
}

/// Orders conversations for the Home sidebar: deleted ones hidden, the
/// user's own space first, then pinned ones, then the most recent, as in the
/// DMs tab.
List<DmConversation> homeSidebarDmOrder(
  List<DmConversation> conversations, {
  required DmConversationActions actions,
  required String? ownUserId,
}) {
  final visible =
      conversations
          .where((c) => !actions.deletedIds.contains(c.channelId))
          .toList()
        ..sort((a, b) {
          final aPinned = actions.pinnedIds.contains(a.channelId);
          final bPinned = actions.pinnedIds.contains(b.channelId);
          if (aPinned != bPinned) return aPinned ? -1 : 1;
          return b.lastActivityAt.compareTo(a.lastActivityAt);
        });
  final ownIndex = visible.indexWhere((c) => c.isOwnSpaceFor(ownUserId));
  if (ownIndex > 0) visible.insert(0, visible.removeAt(ownIndex));
  return visible;
}

/// The conversations under the Direct messages heading.
class SidebarDmList extends ConsumerWidget {
  const SidebarDmList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final dmState = ref.watch(dmListProvider);
    final actions = ref.watch(dmConversationActionsProvider);
    final userId = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    final selected = ref.watch(selectedDmProvider);

    Widget message(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          color: colors.onPrimary.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
    );

    final conversations = dmState.value;
    if (conversations == null) {
      return message(
        dmState.hasError
            ? "Couldn't load direct messages"
            : 'Loading direct messages…',
      );
    }

    final ordered = homeSidebarDmOrder(
      conversations,
      actions: actions,
      ownUserId: userId,
    );
    if (ordered.isEmpty) return message('No direct messages yet');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      // Transparent Material so each row's hover and selected ink paints
      // above the sidebar colour.
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            for (final conversation in ordered)
              _SidebarDmItem(
                conversation: conversation,
                isOwnSpace: conversation.isOwnSpaceFor(userId),
                selected:
                    selected?.conversationKey == conversation.conversationKey,
                onTap: () {
                  ref.read(selectedDmProvider.notifier).select(conversation);
                  ref
                      .read(homeSidebarProvider.notifier)
                      .setType(HomeSidebarType.dms);
                },
                onSecondaryTap: (position) =>
                    showDmRowMenu(context, ref, conversation, position),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarDmItem extends StatelessWidget {
  final DmConversation conversation;
  final bool isOwnSpace;
  final bool selected;
  final VoidCallback onTap;

  /// Called with the global position of a right-click on the row.
  final ValueChanged<Offset> onSecondaryTap;

  const _SidebarDmItem({
    required this.conversation,
    required this.isOwnSpace,
    required this.selected,
    required this.onTap,
    required this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(6);
    final name = conversation.displayName;
    final label = isOwnSpace ? '$name (you)' : name;
    final avatarUrl = conversation.effectiveAvatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final emphasised = selected || conversation.unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Ink(
        decoration: BoxDecoration(
          color: selected
              ? colors.onPrimary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: borderRadius,
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          onSecondaryTapUp: (details) => onSecondaryTap(details.globalPosition),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: colors.primary,
                  backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          avatarInitial(name),
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 15,
                      fontWeight: emphasised ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
