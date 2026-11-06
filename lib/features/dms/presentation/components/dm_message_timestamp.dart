import 'package:zedu/core/core.dart';

/// Calendar context for a message, using the person's local date and clock.
String formatDmMessageTimestamp(
  DateTime createdAt, {
  required DateTime now,
  required MaterialLocalizations localizations,
  required bool use24HourFormat,
}) {
  final local = createdAt.toLocal();
  final today = now.toLocal();
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: use24HourFormat,
  );
  if (local.year == today.year &&
      local.month == today.month &&
      local.day == today.day) {
    return time;
  }
  return '${localizations.formatShortDate(local)} · $time';
}
