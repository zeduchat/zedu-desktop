import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The menu values the save and reminder entries use, shared by the direct
/// message and channel menus so the two cannot drift apart.
class SavedMenuAction {
  static const save = 'saved.save';
  static const unsave = 'saved.unsave';
  static const remind = 'saved.remind';
  static const clearReminder = 'saved.clearReminder';
}

/// How a reminder time reads to the user: the time alone today, the weekday
/// and time within the week, otherwise the date.
String formatReminder(BuildContext context, DateTime when, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final time = TimeOfDay.fromDateTime(when).format(context);
  final sameDay =
      when.year == today.year &&
      when.month == today.month &&
      when.day == today.day;
  if (sameDay) return 'Today, $time';

  final tomorrow = today.add(const Duration(days: 1));
  final isTomorrow =
      when.year == tomorrow.year &&
      when.month == tomorrow.month &&
      when.day == tomorrow.day;
  if (isTomorrow) return 'Tomorrow, $time';

  const months = [
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
  return '${months[when.month - 1]} ${when.day}, $time';
}

/// The save and reminder entries for a message menu. They are offered on every
/// message, the user's own and other people's alike.
List<PopupMenuEntry<String>> savedMenuEntries({required bool isSaved}) => [
  PopupMenuItem<String>(
    value: isSaved ? SavedMenuAction.unsave : SavedMenuAction.save,
    child: Text(isSaved ? 'Remove from saved' : 'Save for later'),
  ),
  const PopupMenuItem<String>(
    value: SavedMenuAction.remind,
    child: Text('Remind me about this'),
  ),
];

/// Runs a save or reminder menu selection, reporting the outcome.
///
/// Returns true when [value] was one of these entries, so a caller's own
/// actions still reach their own handler.
Future<bool> handleSavedMenuAction(
  BuildContext context,
  WidgetRef ref,
  String value,
  SavedTarget target,
) async {
  switch (value) {
    case SavedMenuAction.save:
      await _run(
        context,
        () => ref.read(savedProvider.notifier).save(target),
        success: 'Saved for later.',
        failure: 'Could not save that message.',
      );
      return true;
    case SavedMenuAction.unsave:
      await _run(
        context,
        () => ref.read(savedProvider.notifier).removeTarget(target),
        success: 'Removed from saved.',
        failure: 'Could not remove that saved message.',
      );
      return true;
    case SavedMenuAction.remind:
      await promptForReminder(context, ref, target);
      return true;
    case SavedMenuAction.clearReminder:
      await clearReminder(context, ref, target);
      return true;
    default:
      return false;
  }
}

/// Asks which reminder time, and sets it on the server.
Future<void> promptForReminder(
  BuildContext context,
  WidgetRef ref,
  SavedTarget target,
) async {
  final preset = await showReminderPicker(context);
  if (preset == null) return;
  if (!context.mounted) return;

  final label = formatReminder(context, preset.resolve(DateTime.now()));
  await _run(
    context,
    () => ref
        .read(savedProvider.notifier)
        .setReminder(target: target, preset: preset),
    success: "We'll remind you at $label.",
    failure: 'Could not set that reminder.',
  );
}

/// Cancels the pending reminder on a message.
Future<void> clearReminder(
  BuildContext context,
  WidgetRef ref,
  SavedTarget target,
) async {
  await _run(
    context,
    () => ref.read(savedProvider.notifier).clearReminder(target),
    success: 'Reminder cancelled.',
    failure: 'Could not cancel that reminder.',
  );
}

Future<void> _run(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
  required String failure,
}) async {
  // Captured before the await: the menu's own context can be gone by the time
  // the request answers.
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  try {
    await action();
    if (overlay == null) return;
    AppToastService.showWith(
      overlay,
      type: AppToastType.success,
      message: success,
    );
  } catch (_) {
    if (overlay == null) return;
    // The failure is shown rather than swallowed: a reminder the server did
    // not accept must not look as though it was set.
    AppToastService.showWith(
      overlay,
      type: AppToastType.error,
      message: failure,
    );
  }
}

/// The reminder choices the server accepts.
Future<ReminderPreset?> showReminderPicker(BuildContext context) {
  return showDialog<ReminderPreset>(
    context: context,
    builder: (context) => const ReminderPickerDialog(),
  );
}

/// The reminder choices.
///
/// There is no custom time: the endpoint the web client uses accepts only
/// these three presets and rejects anything else, and the server resolves
/// them itself.
class ReminderPickerDialog extends StatelessWidget {
  const ReminderPickerDialog({super.key, this.now});

  /// Injected by tests so the presets resolve against a known clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clock = now ?? DateTime.now();

    return Dialog(
      backgroundColor: colors.background,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Remind me about this',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Scrollable, so the choices still fit in a short window rather
            // than overflowing.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final preset in ReminderPreset.values)
                      ListTile(
                        dense: true,
                        title: Text(
                          preset.label,
                          style: TextStyle(color: colors.textPrimary),
                        ),
                        trailing: Text(
                          formatReminder(
                            context,
                            preset.resolve(clock),
                            now: clock,
                          ),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(preset),
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
