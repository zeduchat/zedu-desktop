import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Asks before archiving [channel], then archives it.
Future<void> confirmArchiveChannel(
  BuildContext context,
  WidgetRef ref,
  Channel channel,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Archive #${channel.name}?'),
      content: const Text(
        'It leaves the sidebar for everyone and its history is kept. '
        'You can unarchive it from the channel directory.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Archive'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await setChannelArchived(context, ref, channel, archived: true);
}

/// Archives or unarchives [channel] and says how it went.
Future<void> setChannelArchived(
  BuildContext context,
  WidgetRef ref,
  Channel channel, {
  required bool archived,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final result = await ref
      .read(channelProvider.notifier)
      .archiveChannel(channel, archived: archived);

  switch (result) {
    case Success<void>():
      if (archived) {
        // Open another channel so the header never shows an archived one.
        final remaining = ref.read(channelProvider).value ?? const <Channel>[];
        ref
            .read(activeChatProvider.notifier)
            .selectChannel(
              remaining.isEmpty ? 'general' : remaining.first.name,
            );
      }
      AppToastService.showWith(
        overlay,
        type: AppToastType.success,
        message: archived
            ? '#${channel.name} was archived'
            : '#${channel.name} was unarchived',
      );
    case Failure<void>(:final error):
      AppToastService.showWith(
        overlay,
        type: AppToastType.error,
        message: archiveFailureMessage(error, channel, archived: archived),
      );
  }
}

/// Asks before leaving [channel], then leaves it.
Future<void> confirmLeaveChannel(
  BuildContext context,
  WidgetRef ref,
  Channel channel,
) async {
  final colors = context.colors;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Leave #${channel.name}?'),
      content: Text(
        channel.isPrivate
            ? 'You will stop getting its messages, and someone will need to '
                  'add you again to rejoin.'
            : 'You will stop getting its messages. You can join it again '
                  'from the channel directory.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Leave', style: TextStyle(color: colors.error)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final overlay = Overlay.of(context, rootOverlay: true);
  final result = await ref
      .read(channelProvider.notifier)
      .leaveChannel(channel.id);

  switch (result) {
    case Success<void>():
      // Open another channel so the header never shows one we left.
      final remaining = (ref.read(channelProvider).value ?? const <Channel>[])
          .where((c) => !c.archived && c.hasAccess)
          .toList();
      ref
          .read(activeChatProvider.notifier)
          .selectChannel(remaining.isEmpty ? 'general' : remaining.first.name);
      AppToastService.showWith(
        overlay,
        type: AppToastType.success,
        message: 'You left #${channel.name}',
      );
    case Failure<void>(:final error):
      AppToastService.showWith(
        overlay,
        type: AppToastType.error,
        message: switch (error.kind) {
          ApiFailureKind.unknown || ApiFailureKind.parsing =>
            'Could not leave #${channel.name}. Please try again.',
          _ =>
            error.friendlyMessage.isEmpty
                ? 'Could not leave #${channel.name}'
                : error.friendlyMessage,
        },
      );
  }
}
