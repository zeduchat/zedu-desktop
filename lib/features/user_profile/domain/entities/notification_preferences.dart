enum NotificationMode { allMessages, mentionsOnly, none }

/// Formats minutes after midnight as the backend's `h:mm AM` form.
String formatMinutesOfDay(int minutes) {
  final normalized = minutes % NotificationPreferences.minutesPerDay;
  final hour24 = normalized ~/ 60;
  final minute = (normalized % 60).toString().padLeft(2, '0');
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:$minute ${hour24 < 12 ? 'AM' : 'PM'}';
}

/// Parses `h:mm AM`, `hh:mm PM` or 24-hour `HH:mm` into minutes after midnight.
int? parseMinutesOfDay(String value) {
  final match = RegExp(
    r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])?\s*$',
  ).firstMatch(value);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final period = match.group(3)?.toUpperCase();
  if (minute > 59) return null;
  if (period == null) {
    if (hour > 23) return null;
  } else {
    if (hour < 1 || hour > 12) return null;
    if (period == 'AM' && hour == 12) hour = 0;
    if (period == 'PM' && hour < 12) hour += 12;
  }
  return hour * 60 + minute;
}

/// The user's desktop notification preferences for one workspace.
///
/// Times are minutes after midnight in the user's profile [timezone], which is
/// where the backend evaluates the schedule.
class NotificationPreferences {
  const NotificationPreferences({
    required this.mode,
    required this.quietHoursEnabled,
    required this.pauseFrom,
    required this.resumeAt,
    required this.emailNotifications,
    required this.differentMobileSettings,
    this.timezone,
  });

  factory NotificationPreferences.empty() => const NotificationPreferences(
    mode: NotificationMode.allMessages,
    quietHoursEnabled: false,
    pauseFrom: defaultPauseFrom,
    resumeAt: defaultResumeAt,
    emailNotifications: false,
    differentMobileSettings: false,
  );

  /// 10:00 PM, used when quiet hours are switched on for the first time.
  static const defaultPauseFrom = 22 * 60;

  /// 7:00 AM, used when quiet hours are switched on for the first time.
  static const defaultResumeAt = 7 * 60;

  static const minutesPerDay = 24 * 60;

  final NotificationMode mode;
  final bool quietHoursEnabled;
  final int pauseFrom;
  final int resumeAt;
  final bool emailNotifications;

  /// Off: mobile devices get the same settings as this desktop when saving.
  /// On: mobile keeps its own settings, managed in the Zedu mobile app.
  final bool differentMobileSettings;

  /// IANA name from the user's profile, or null when none is set (the backend
  /// then uses UTC).
  final String? timezone;

  /// Whether the quiet period wraps past midnight, e.g. 10:00 PM to 7:00 AM.
  bool get quietHoursCrossMidnight => resumeAt <= pauseFrom;

  /// Quiet hours need a non-empty period to mean anything.
  bool get hasValidQuietHours => !quietHoursEnabled || pauseFrom != resumeAt;

  NotificationPreferences copyWith({
    NotificationMode? mode,
    bool? quietHoursEnabled,
    int? pauseFrom,
    int? resumeAt,
    bool? emailNotifications,
    bool? differentMobileSettings,
    String? timezone,
  }) {
    return NotificationPreferences(
      mode: mode ?? this.mode,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      pauseFrom: pauseFrom ?? this.pauseFrom,
      resumeAt: resumeAt ?? this.resumeAt,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      differentMobileSettings:
          differentMobileSettings ?? this.differentMobileSettings,
      timezone: timezone ?? this.timezone,
    );
  }

  /// Compares what would actually be saved. The pause and resume times are
  /// ignored while quiet hours are off, so switching quiet hours off and back
  /// on with the same times does not count as a change.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationPreferences &&
        other.mode == mode &&
        other.quietHoursEnabled == quietHoursEnabled &&
        (!quietHoursEnabled ||
            (other.pauseFrom == pauseFrom && other.resumeAt == resumeAt)) &&
        other.emailNotifications == emailNotifications &&
        other.differentMobileSettings == differentMobileSettings &&
        other.timezone == timezone;
  }

  @override
  int get hashCode => Object.hash(
    mode,
    quietHoursEnabled,
    quietHoursEnabled ? pauseFrom : null,
    quietHoursEnabled ? resumeAt : null,
    emailNotifications,
    differentMobileSettings,
    timezone,
  );
}
