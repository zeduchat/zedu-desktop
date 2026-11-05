import 'package:zedu/core/core.dart';

/// Which messages in a channel notify the user, the same three choices the
/// web offers: every new message, only mentions of them, or only @channel.
enum ChannelNotificationLevel { all, mentions, channels }

/// The user's notification choice for one channel.
class ChannelNotificationPreference {
  const ChannelNotificationPreference({
    this.level = ChannelNotificationLevel.all,
    this.muted = false,
  });

  final ChannelNotificationLevel level;
  final bool muted;

  /// Reads the backend's `at_channel`, `at_mentions` and `muted` flags the
  /// way the web does.
  factory ChannelNotificationPreference.fromJson(Map<String, dynamic> json) {
    final atChannel = json['at_channel'] == true;
    final atMentions = json['at_mentions'] == true;
    return ChannelNotificationPreference(
      level: atChannel && atMentions
          ? ChannelNotificationLevel.all
          : atMentions
          ? ChannelNotificationLevel.mentions
          : ChannelNotificationLevel.channels,
      muted: json['muted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'muted': muted,
    'at_mentions':
        level == ChannelNotificationLevel.all ||
        level == ChannelNotificationLevel.mentions,
    'at_channel':
        level == ChannelNotificationLevel.all ||
        level == ChannelNotificationLevel.channels,
    'device_type': ChannelNotificationService.deviceType,
  };

  ChannelNotificationPreference copyWith({
    ChannelNotificationLevel? level,
    bool? muted,
  }) => ChannelNotificationPreference(
    level: level ?? this.level,
    muted: muted ?? this.muted,
  );
}

/// Loads and saves a channel's notification preference through
/// `/channels/{id}/notification-preference`, the endpoint the web uses.
class ChannelNotificationService {
  ChannelNotificationService(this._api);

  final ApiBaseService _api;

  static const deviceType = 'desktop';

  Future<ChannelNotificationPreference> load(String channelId) async {
    final response = await _api.get<Map<String, dynamic>>(
      path: '/channels/$channelId/notification-preference',
      queryParameters: {'device_type': deviceType},
    );
    final data = response.data['data'];
    return data is Map<String, dynamic>
        ? ChannelNotificationPreference.fromJson(data)
        : const ChannelNotificationPreference();
  }

  Future<void> save(
    String channelId,
    ChannelNotificationPreference preference,
  ) async {
    await _api.post<Map<String, dynamic>>(
      path: '/channels/$channelId/notification-preference',
      data: preference.toJson(),
    );
  }
}

final channelNotificationServiceProvider = Provider<ChannelNotificationService>(
  (ref) => ChannelNotificationService(locator<ApiBaseService>()),
);
