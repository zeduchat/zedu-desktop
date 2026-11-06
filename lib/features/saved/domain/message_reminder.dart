/// The three reminder times the server accepts.
///
/// The server resolves these itself, so the client sends the choice rather
/// than an instant: the request model validates
/// `oneof=30_min 1_hour tomorrow_9am` and rejects anything else. There is no
/// custom time on this endpoint.
enum ReminderPreset {
  inThirtyMinutes('30_min', 'In 30 minutes'),
  inOneHour('1_hour', 'In 1 hour'),
  tomorrowMorning('tomorrow_9am', 'Tomorrow at 9:00 AM');

  const ReminderPreset(this.wire, this.label);

  final String wire;
  final String label;

  static ReminderPreset? fromWire(String? value) {
    for (final preset in ReminderPreset.values) {
      if (preset.wire == value) return preset;
    }
    return null;
  }

  /// A local preview of when this preset lands, shown beside the choice.
  ///
  /// The server computes the real instant; this only has to agree with it,
  /// and does: the fixed durations are added to now, and tomorrow at 9 is
  /// resolved in the caller's own day, which is why the request carries the
  /// client's UTC offset.
  DateTime resolve(DateTime now) => switch (this) {
    ReminderPreset.inThirtyMinutes => now.add(const Duration(minutes: 30)),
    ReminderPreset.inOneHour => now.add(const Duration(hours: 1)),
    ReminderPreset.tomorrowMorning => DateTime(
      now.year,
      now.month,
      now.day + 1,
      9,
    ),
  };
}

/// A pending reminder on a message, as the server reports it.
///
/// The list endpoint returns only reminders that have not fired yet
/// (`sent_at IS NULL`), soonest first, so a reminder disappears from here once
/// it has been delivered.
class MessageReminder {
  const MessageReminder({
    required this.id,
    required this.channelId,
    required this.threadId,
    required this.remindAt,
    this.messageId,
    this.preset,
  });

  final String id;
  final String channelId;
  final String threadId;
  final String? messageId;
  final DateTime remindAt;
  final ReminderPreset? preset;

  /// Matches `SavedTarget.key`, so a saved row can find its reminder.
  String get key => '$channelId:${messageId ?? threadId}';

  /// Whether the time has passed while the reminder is still pending. The
  /// server does not report this: it drops a reminder from the list once it
  /// has been sent, so this is only the short window before delivery.
  bool isDue(DateTime now) => remindAt.isBefore(now);

  static String _string(Object? value) => value?.toString() ?? '';

  factory MessageReminder.fromJson(Map<String, dynamic> json) {
    final rawMessageId = _string(json['message_id']);
    return MessageReminder(
      id: _string(json['id']),
      channelId: _string(json['channels_id']),
      threadId: _string(json['thread_id']),
      messageId: rawMessageId.isEmpty ? null : rawMessageId,
      remindAt:
          DateTime.tryParse(_string(json['remind_at']))?.toLocal() ??
          DateTime.now(),
      preset: ReminderPreset.fromWire(json['preset'] as String?),
    );
  }
}
