import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(locator<ApiBaseService>());
});

/// Message reminders, on the same endpoints the web client uses, so a
/// reminder set on desktop appears in the web app's Reminders list and the
/// other way round.
class ReminderRepository {
  ReminderRepository(this._apiClient);

  final ApiBaseService _apiClient;

  /// Pending reminders, soonest first. The server returns only those that
  /// have not fired yet.
  Future<List<MessageReminder>> list({required String orgId}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      path: '/organisations/$orgId/reminders',
    );

    final raw = response.data['data'];
    return (raw is List ? raw : const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MessageReminder.fromJson)
        .where((reminder) => reminder.id.isNotEmpty)
        .toList();
  }

  /// Creates a reminder from a preset.
  ///
  /// [tzOffsetMinutes] is the client's own offset from UTC, in minutes east.
  /// Only `tomorrow_9am` depends on it, since 9 AM is a wall-clock time in
  /// the user's day rather than a fixed instant, but it is always sent:
  /// omitting it would schedule 09:00 UTC, the wrong morning for most users.
  Future<MessageReminder> create({
    required String orgId,
    required SavedTarget target,
    required ReminderPreset preset,
    required int tzOffsetMinutes,
  }) async {
    final messageId = target.messageId;
    final response = await _apiClient.post<Map<String, dynamic>>(
      path: '/organisations/$orgId/reminders',
      data: {
        'channels_id': target.channelId,
        'thread_id': target.threadId,
        'message_id': ?messageId,
        'type': target.kind.wire,
        'preset': preset.wire,
        'tz_offset_minutes': tzOffsetMinutes,
      },
    );

    final data = response.data['data'];
    return MessageReminder.fromJson(
      data is Map<String, dynamic> ? data : const {},
    );
  }

  Future<void> delete({
    required String orgId,
    required String reminderId,
  }) async {
    await _apiClient.delete<Map<String, dynamic>>(
      path: '/organisations/$orgId/reminders/$reminderId',
    );
  }
}
