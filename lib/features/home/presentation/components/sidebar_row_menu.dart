import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

RelativeRect _menuPosition(BuildContext context, Offset position) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return RelativeRect.fromRect(
    position & const Size(1, 1),
    Offset.zero & overlay.size,
  );
}

PopupMenuItem<String> _menuItem(
  BuildContext context,
  String value,
  String label, {
  bool destructive = false,
}) {
  final colors = context.colors;
  return PopupMenuItem<String>(
    value: value,
    child: Text(
      label,
      style: TextStyle(color: destructive ? colors.error : colors.textPrimary),
    ),
  );
}

/// The menu a right-click on a channel in the sidebar opens, at [position]
/// (global). It has the actions the channel header menu has: archive and
/// leave, each asking first.
Future<void> showChannelRowMenu(
  BuildContext context,
  WidgetRef ref,
  Channel channel,
  Offset position,
) async {
  final choice = await showMenu<String>(
    context: context,
    position: _menuPosition(context, position),
    items: [
      _menuItem(context, 'archive', 'Archive channel'),
      _menuItem(context, 'leave', 'Leave channel', destructive: true),
    ],
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'archive':
      await confirmArchiveChannel(context, ref, channel);
    case 'leave':
      await confirmLeaveChannel(context, ref, channel);
  }
}

/// The menu a right-click on a direct message in the sidebar opens, at
/// [position] (global). It has the actions the DM header menu has that work
/// from a list: pin, mute and delete (which asks first).
Future<void> showDmRowMenu(
  BuildContext context,
  WidgetRef ref,
  DmConversation conversation,
  Offset position,
) async {
  // Someone you have not messaged yet has no conversation to pin or delete.
  if (conversation.channelId.isEmpty) return;

  final pinned = ref
      .read(dmConversationActionsProvider)
      .pinnedIds
      .contains(conversation.channelId);
  final muted = ref
      .read(notificationSettingsProvider)
      .isMuted(conversation.participantId);

  final choice = await showMenu<String>(
    context: context,
    position: _menuPosition(context, position),
    items: [
      _menuItem(
        context,
        'pin',
        pinned ? 'Unpin conversation' : 'Pin conversation',
      ),
      _menuItem(
        context,
        'mute',
        muted ? 'Unmute notifications' : 'Mute notifications',
      ),
      const PopupMenuDivider(),
      _menuItem(context, 'delete', 'Delete conversation', destructive: true),
    ],
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'pin':
      ref
          .read(dmConversationActionsProvider.notifier)
          .togglePinned(conversation.channelId);
    case 'mute':
      final notifier = ref.read(notificationSettingsProvider.notifier);
      if (muted) {
        notifier.unmuteParticipant(conversation.participantId);
      } else {
        notifier.muteParticipant(conversation.participantId);
      }
    case 'delete':
      await _confirmDeleteDm(context, ref, conversation);
  }
}

Future<void> _confirmDeleteDm(
  BuildContext context,
  WidgetRef ref,
  DmConversation conversation,
) async {
  final colors = context.colors;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete conversation?'),
      content: Text(
        'This removes the conversation from your DM list. '
        '${conversation.displayName} can still see it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: colors.error),
          child: const Text('Delete conversation'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final overlay = Overlay.of(context, rootOverlay: true);
  final deleted = await ref
      .read(dmConversationActionsProvider.notifier)
      .delete(conversation.channelId);
  if (!deleted) {
    AppToastService.showWith(
      overlay,
      type: AppToastType.error,
      message: "Couldn't delete the conversation. Try again.",
    );
  }
}
