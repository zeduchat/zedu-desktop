import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ProfileAccountModel extends ProfileAccount {
  const ProfileAccountModel({
    required super.name,
    required super.email,
    required super.timezone,
    super.avatarUrl,
    super.displayName,
    super.username,
    super.phoneNumber,
    super.title,
    super.namePronunciation,
    super.country,
  });

  factory ProfileAccountModel.fromAccount(ProfileAccount account) {
    return ProfileAccountModel(
      name: account.name,
      email: account.email,
      timezone: account.timezone,
      avatarUrl: account.avatarUrl,
      displayName: account.displayName,
      username: account.username,
      phoneNumber: account.phoneNumber,
      title: account.title,
      namePronunciation: account.namePronunciation,
      country: account.country,
    );
  }

  factory ProfileAccountModel.fromJson(Map<String, dynamic> json) {
    return ProfileAccountModel(
      name:
          json['full_name'] as String? ??
          json['name'] as String? ??
          'Anonymous user',
      email: json['email'] as String? ?? 'anonymoususer@email.com',
      timezone: json['timezone'] as String? ?? 'Africa/Lagos',
      avatarUrl: json['avatar_url'] as String?,
      displayName: json['display_name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      phoneNumber:
          json['phone'] as String? ?? json['phone_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      namePronunciation:
          json['name_pronounciation'] as String? ??
          json['name_pronunciation'] as String? ??
          '',
      country: json['country'] as String? ?? '',
    );
  }
  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'timezone': timezone,
    'avatar_url': avatarUrl,
    'display_name': displayName,
    'username': username,
    'phone_number': phoneNumber,
    'title': title,
    'name_pronunciation': namePronunciation,
    'country': country,
  };
}

/// Maps the per-device organisation preferences
/// (`/organisations/{id}/notification-preference`) to the settings screen.
///
/// The backend stores `time_range` as the window in which notifications are
/// delivered, inclusive at both ends. Quiet hours are the rest of the day, so
/// "pause from 10:00 PM, resume at 7:00 AM" is stored as
/// `7:00 AM - 9:59 PM`.
class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    required super.mode,
    required super.quietHoursEnabled,
    required super.pauseFrom,
    required super.resumeAt,
    required super.emailNotifications,
    required super.differentMobileSettings,
    super.timezone,
  });

  /// [mobile] is the mobile device's preferences. Mobile counts as having its
  /// own settings when they differ from the desktop's.
  factory NotificationPreferencesModel.fromDeviceJson(
    Map<String, dynamic> desktop, {
    Map<String, dynamic>? mobile,
    String? timezone,
  }) {
    final window = _parseWindow(desktop['time_range'] as String?);
    final quietHours = window == null ? null : _quietHoursFor(window);
    return NotificationPreferencesModel(
      mode: _modeFromJson(desktop['notify_about'] as String?),
      quietHoursEnabled: quietHours != null,
      pauseFrom: quietHours?.$1 ?? NotificationPreferences.defaultPauseFrom,
      resumeAt: quietHours?.$2 ?? NotificationPreferences.defaultResumeAt,
      emailNotifications: desktop['send_mail'] as bool? ?? false,
      differentMobileSettings:
          mobile != null && !_sameDeviceSettings(desktop, mobile),
      timezone: (timezone?.isEmpty ?? true) ? null : timezone,
    );
  }

  NotificationPreferencesModel copyWithModel({bool? differentMobileSettings}) {
    return NotificationPreferencesModel(
      mode: mode,
      quietHoursEnabled: quietHoursEnabled,
      pauseFrom: pauseFrom,
      resumeAt: resumeAt,
      emailNotifications: emailNotifications,
      differentMobileSettings:
          differentMobileSettings ?? this.differentMobileSettings,
      timezone: timezone,
    );
  }

  /// Delivery window used when quiet hours are off.
  static const allDay = '12:00 AM - 11:59 PM';

  static Map<String, dynamic> toDeviceJson(
    NotificationPreferences preferences, {
    required String deviceType,
  }) {
    return {
      'notify_about': _modeToJson(preferences.mode),
      'send_mail': preferences.emailNotifications,
      'time_range': _timeRangeFor(preferences),
      'device_type': deviceType,
    };
  }

  static String _timeRangeFor(NotificationPreferences preferences) {
    if (!preferences.quietHoursEnabled) return allDay;
    final lastDelivered = preferences.pauseFrom - 1;
    return '${formatMinutesOfDay(preferences.resumeAt)} - '
        '${formatMinutesOfDay(lastDelivered)}';
  }

  static (int, int)? _parseWindow(String? value) {
    final parts = value?.split('-');
    if (parts == null || parts.length != 2) return null;
    final start = parseMinutesOfDay(parts[0]);
    final end = parseMinutesOfDay(parts[1]);
    if (start == null || end == null) return null;
    return (start, end);
  }

  /// Returns (pauseFrom, resumeAt), or null when the window covers the day.
  static (int, int)? _quietHoursFor((int, int) window) {
    final (start, end) = window;
    final pauseFrom = (end + 1) % NotificationPreferences.minutesPerDay;
    if (pauseFrom == start) return null;
    return (pauseFrom, start);
  }

  static bool _sameDeviceSettings(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    return _modeFromJson(a['notify_about'] as String?) ==
            _modeFromJson(b['notify_about'] as String?) &&
        (a['send_mail'] as bool? ?? false) ==
            (b['send_mail'] as bool? ?? false) &&
        _effectiveWindow(a['time_range'] as String?) ==
            _effectiveWindow(b['time_range'] as String?);
  }

  /// Null stands for "all day", however it was written.
  static (int, int)? _effectiveWindow(String? value) {
    final window = _parseWindow(value);
    return window == null || _quietHoursFor(window) == null ? null : window;
  }

  static NotificationMode _modeFromJson(String? value) {
    return switch (value) {
      'mentions' || 'direct_messages_mentions' => NotificationMode.mentionsOnly,
      'nothing' => NotificationMode.none,
      _ => NotificationMode.allMessages,
    };
  }

  static String _modeToJson(NotificationMode mode) {
    return switch (mode) {
      NotificationMode.allMessages => 'all_new_messages',
      NotificationMode.mentionsOnly => 'mentions',
      NotificationMode.none => 'nothing',
    };
  }
}

class OrganizationProfileModel extends OrganizationProfile {
  const OrganizationProfileModel({
    required super.id,
    required super.name,
    required super.natureOfBusiness,
    required super.country,
  });

  factory OrganizationProfileModel.fromJson(Map<String, dynamic> json) {
    return OrganizationProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      natureOfBusiness:
          json['nature_of_business'] as String? ??
          json['type'] as String? ??
          '',
      country: countryDisplayName(json['country'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nature_of_business': natureOfBusiness,
    'country': country,
  };
}

class SecuritySessionModel extends SecuritySession {
  const SecuritySessionModel({
    required super.device,
    required super.location,
    required super.date,
    required super.lastActive,
    required super.status,
  });

  /// Reads a session from `GET /users/{id}/sessions` (`created_at`,
  /// `updated_at`, `is_live`) or from the mock data (display strings). The
  /// API gives no device or location, so those show [unknown] rather than
  /// made-up values.
  factory SecuritySessionModel.fromJson(Map<String, dynamic> json) {
    final isLive = json['is_live'];
    return SecuritySessionModel(
      device: _text(json['device']) ?? unknown,
      location: _text(json['location']) ?? unknown,
      date: _text(json['date']) ?? _formatTime(json['created_at']) ?? unknown,
      lastActive:
          _text(json['last_active']) ??
          _formatTime(json['updated_at']) ??
          unknown,
      status:
          _text(json['status']) ??
          (isLive is bool ? (isLive ? 'Active' : 'Signed out') : unknown),
    );
  }

  /// Shown for a detail the server doesn't send.
  static const unknown = '—';

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "May 8, 2026 1:07 PM" in local time, or null when [value] isn't a time.
  static String? _formatTime(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) return null;
    final t = parsed.toLocal();
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '${_months[t.month - 1]} ${t.day}, ${t.year} $hour:$minute $period';
  }
}

class TeamMemberModel extends TeamMember {
  const TeamMemberModel({
    required super.id,
    required super.email,
    required super.role,
    required super.dateJoined,
    required super.status,
    super.name,
    super.avatarUrl,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: json['id'] as String? ?? 'member-1',
      email: json['email'] as String? ?? 'anonymoususer@gmail.com',
      role: json['role'] as String? ?? 'Administrator',
      dateJoined: json['date_joined'] as String? ?? 'May 3, 2026',
      status: statusFromJson(json),
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  /// Reads a member's status from an API record: `status` ("pending",
  /// "inactive", any case), and `is_deactivated: true` counts as inactive.
  /// Anything else is active.
  static TeamMemberStatus statusFromJson(Map<String, dynamic> json) {
    if (json['is_deactivated'] == true) return TeamMemberStatus.inactive;
    final value = json['status'];
    return switch (value is String ? value.trim().toLowerCase() : null) {
      'pending' => TeamMemberStatus.pending,
      'inactive' => TeamMemberStatus.inactive,
      _ => TeamMemberStatus.active,
    };
  }
}

class RolePermissionModel extends RolePermission {
  const RolePermissionModel({
    super.id,
    required super.role,
    required super.description,
    required super.permissions,
  });

  /// Reads a role from `GET /organisations/{orgId}/roles`, shaped like
  /// `{"name": "Admin", "description": "...", "permissions":
  /// {"permission_list": {"can_manage_channels": true, ...}}}`.
  /// The older `{"role": ..., "permissions": ["..."]}` shape (mock data)
  /// still reads.
  factory RolePermissionModel.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? json['role'];
    return RolePermissionModel(
      id: json['id']?.toString(),
      role: name is String && name.trim().isNotEmpty ? name : 'User',
      description: json['description'] as String? ?? '',
      permissions: _readPermissions(json['permissions']),
    );
  }

  static List<String> _readPermissions(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    if (raw is Map) {
      final list = raw['permission_list'];
      final flags = list is Map ? list : raw;
      return [
        for (final entry in flags.entries)
          if (entry.value == true) _permissionLabel(entry.key.toString()),
      ];
    }
    return const [];
  }

  /// `can_manage_channels` -> `Manage channels`.
  static String _permissionLabel(String key) {
    final words = key.replaceFirst(RegExp('^can_'), '').split('_')
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return key;
    final text = words.join(' ');
    return text[0].toUpperCase() + text.substring(1);
  }
}

class BillingInfoModel extends BillingInfo {
  const BillingInfoModel({
    required super.plan,
    required super.description,
    super.paymentHistory,
  });

  factory BillingInfoModel.fromJson(Map<String, dynamic> json) {
    return BillingInfoModel(
      plan: json['plan'] as String? ?? 'Zedu Free',
      description: json['description'] as String? ?? '',
      paymentHistory:
          (json['payment_history'] as List<dynamic>?)
              ?.map(
                (e) => PaymentRecordModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}

class PaymentRecordModel extends PaymentRecord {
  const PaymentRecordModel({
    required super.id,
    required super.description,
    required super.amount,
    required super.date,
    required super.status,
  });

  factory PaymentRecordModel.fromJson(Map<String, dynamic> json) {
    return PaymentRecordModel(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? 'Subscription Payment',
      amount: json['amount'] as String? ?? '',
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}
