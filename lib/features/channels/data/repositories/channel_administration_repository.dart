import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Organization response uses the same user_role fields as the web client.
bool canAdministerChannels(Map<String, dynamic> organization) {
  final role = organization['user_role'];
  final name = (role is Map ? role['role_name'] : organization['role'])
      ?.toString()
      .toLowerCase();
  final permissions = [
    if (role is Map && role['permissions'] is List)
      ...role['permissions'] as List,
    if (organization['permissions'] is List)
      ...organization['permissions'] as List,
  ];
  return ['owner', 'administrator', 'manager'].contains(name) ||
      permissions.contains('manage:channels') ||
      permissions.contains('can_manage_channels');
}

class ManagedChannel {
  const ManagedChannel(this.channel, {this.createdAt, this.memberCount});
  final Channel channel;
  final DateTime? createdAt;
  final int? memberCount;
  factory ManagedChannel.fromJson(Map<String, dynamic> json) => ManagedChannel(
    Channel.fromJson(json),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    memberCount: int.tryParse(
      (json['members_count'] ?? json['user_count'])?.toString() ?? '',
    ),
  );
}

class ChannelAdministrationRepository {
  ChannelAdministrationRepository(this.api);
  final ApiBaseService api;
  Future<List<ManagedChannel>> load(String orgId) async {
    final org = await api.get<Map<String, dynamic>>(
      path: '/organisations/$orgId',
    );
    if (!canAdministerChannels(
      Map<String, dynamic>.from(org.data['data'] as Map),
    )) {
      throw const ApiFailure(
        message: 'You do not have permission to manage channels.',
      );
    }
    final result = <String, ManagedChannel>{};
    for (final suffix in ['', '/archived']) {
      for (var page = 1; page <= 100; page++) {
        final response = await api.get<Map<String, dynamic>>(
          path: '/organisations/$orgId/channels$suffix',
          queryParameters: {'page': page, 'limit': 100},
        );
        final data = response.data['data'];
        if (data is! List) {
          throw const ApiFailure(message: 'Could not read the channel list.');
        }
        var added = 0;
        for (final raw in data.whereType<Map<dynamic, dynamic>>()) {
          final item = ManagedChannel.fromJson(Map<String, dynamic>.from(raw));
          if (item.channel.id.isEmpty ||
              (item.channel.isPrivate && !item.channel.hasAccess)) {
            continue;
          }
          if (!result.containsKey(item.channel.id)) added++;
          result[item.channel.id] = suffix.isEmpty
              ? item
              : ManagedChannel(
                  item.channel.copyWith(archived: true),
                  createdAt: item.createdAt,
                  memberCount: item.memberCount,
                );
        }
        final pagination = response.data['pagination'];
        final pages = pagination is Map
            ? int.tryParse('${pagination['total_pages']}')
            : null;
        if ((pages != null && page >= pages) ||
            data.isEmpty ||
            (pages == null && data.length < 100)) {
          break;
        }
        if (added == 0 || page == 100) {
          throw const ApiFailure(
            message:
                'The channel list could not be fully loaded. Please retry.',
          );
        }
      }
    }
    return result.values.toList();
  }
}

final channelAdministrationRepositoryProvider = Provider(
  (ref) => ChannelAdministrationRepository(locator<ApiBaseService>()),
);
final managedChannelsProvider = FutureProvider<List<ManagedChannel>>((
  ref,
) async {
  final org = ref.watch(
    workspaceProvider.select((s) => s.selectedWorkspace?.id),
  );
  ref.watch(authNotifierProvider.select((s) => s.user?.id));
  if (org == null) return [];
  return ref.watch(channelAdministrationRepositoryProvider).load(org);
}, retry: (_, _) => null);

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The workspace's archived channels. The channel list leaves them out, so
/// the channel directory loads them from here to offer Unarchive.
class ArchivedChannelsNotifier extends AsyncNotifier<List<Channel>> {
  @override
  Future<List<Channel>> build() async {
    final orgId = ref.watch(
      workspaceProvider.select((s) => s.selectedWorkspace?.id),
    );
    if (orgId == null) return const [];

    final result = await ref
        .read(channelRepositoryProvider)
        .fetchArchivedChannels(orgId);

    return switch (result) {
      Success<List<Channel>>(:final value) => value,
      Failure<List<Channel>>(:final error) => throw error,
    };
  }
}

final archivedChannelsProvider =
    AsyncNotifierProvider<ArchivedChannelsNotifier, List<Channel>>(
      ArchivedChannelsNotifier.new,
      retry: (_, _) => null,
    );

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The workspace's archived channels. The channel list leaves them out, so
/// the channel directory loads them from here to offer Unarchive.
class ArchivedChannelsNotifier extends AsyncNotifier<List<Channel>> {
  @override
  Future<List<Channel>> build() async {
    final orgId = ref.watch(
      workspaceProvider.select((s) => s.selectedWorkspace?.id),
    );
    if (orgId == null) return const [];

    final result = await ref
        .read(channelRepositoryProvider)
        .fetchArchivedChannels(orgId);

    return switch (result) {
      Success<List<Channel>>(:final value) => value,
      Failure<List<Channel>>(:final error) => throw error,
    };
  }
}

final archivedChannelsProvider =
    AsyncNotifierProvider<ArchivedChannelsNotifier, List<Channel>>(
      ArchivedChannelsNotifier.new,
      retry: (_, _) => null,
    );
