import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class ChannelRemoteDataSource {
  Future<List<Channel>> fetchChannels(String orgId);
  Future<Channel> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  });
  Future<void> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  });
  Future<void> archiveChannel(String channelId, bool archived);
  Future<void> leaveChannel(String channelId);
  Future<List<String>> fetchOrganisationMemberIds(String orgId);
  Future<List<String>> fetchChannelMemberIds(String channelId);
  Future<List<DmParticipant>> fetchChannelMembers(String channelId);
  Future<void> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  });

  /// The latest messages of a channel, newest first.
  Future<List<ChannelMessage>> fetchChannelMessages(String channelId);

  /// Stars the channel for this user, or unstars it if it is already starred.
  /// Returns whether it is starred now.
  Future<bool> toggleStarChannel({
    required String orgId,
    required String channelId,
  });
}

class ChannelRemoteDataSourceImpl implements ChannelRemoteDataSource {
  final ApiBaseService apiBaseService;

  /// Page size for the paginated member lists (the backend default is 20).
  static const memberPageSize = 100;

  /// Stops paging a broken or endless member list after this many pages.
  static const maxMemberPages = 50;

  ChannelRemoteDataSourceImpl({required this.apiBaseService});

  @override
  Future<List<Channel>> fetchChannels(String orgId) async {
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/organisations/$orgId/channels',
    );
    final data = response.data['data'] as List?;
    if (data == null) return [];
    return data
        .map((e) => Channel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> toggleStarChannel({
    required String orgId,
    required String channelId,
  }) async {
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/organisations/$orgId/channels/$channelId/star',
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    final isStarred = data?['is_starred'] as bool?;
    if (isStarred == null) {
      throw Exception('No star state returned from toggle star');
    }
    return isStarred;
  }

  @override
  Future<Channel> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  }) async {
    final body = {
      'name': name,
      'description': description,
      'organisation_id': orgId,
      'username': username,
      'is_private': isPrivate,
      'topic': ?topic,
    };
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/channels',
      data: body,
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from create channel');
    return Channel.fromJson(data);
  }

  @override
  Future<void> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  }) async {
    final data = <String, dynamic>{};
    if (topic != null) data['topic'] = topic;
    if (description != null) data['description'] = description;

    await apiBaseService.put<Map<String, dynamic>>(
      path: '/channels/$channelId/',
      data: data,
    );
  }

  @override
  Future<void> archiveChannel(String channelId, bool archived) async {
    await apiBaseService.put<Map<String, dynamic>>(
      path: '/channels/$channelId/archive',
      data: {'archived': archived},
    );
  }

  @override
  Future<void> leaveChannel(String channelId) async {
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/channels/$channelId/leave',
    );
  }

  @override
  Future<List<String>> fetchOrganisationMemberIds(String orgId) {
    // People only: this endpoint leaves bots out unless include_bots=true.
    return _fetchAllMemberIds('/organisations/$orgId/users');
  }

  @override
  Future<List<String>> fetchChannelMemberIds(String channelId) {
    return _fetchAllMemberIds('/channels/$channelId/users');
  }

  @override
  Future<List<DmParticipant>> fetchChannelMembers(String channelId) async {
    final members = await _fetchAllMembers('/channels/$channelId/users');
    return [
      for (final member in members)
        if ((member['id'] as String? ?? '').isNotEmpty &&
            _memberField(member, 'username').isNotEmpty)
          DmParticipant(
            userId: member['id'] as String,
            username: _memberField(member, 'username'),
            email: member['email'] as String? ?? '',
            avatarUrl: _memberField(member, 'avatar_url').isEmpty
                ? null
                : _memberField(member, 'avatar_url'),
          ),
    ];
  }

  @override
  Future<void> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  }) async {
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/channels/add-multiple',
      data: {'channel_id': channelId, 'user_ids': userIds},
    );
  }

  @override
  Future<List<ChannelMessage>> fetchChannelMessages(String channelId) async {
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/threads/channels/$channelId',
      queryParameters: {'page': 1, 'limit': 50},
    );
    final data = response.data['data'];
    if (data == null) return const [];
    // A wrong shape throws, so the list shows its retry state.
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(ChannelMessage.fromJson)
        .toList();
  }

  // The channel users route nests username and avatar_url under profile.
  String _memberField(Map<String, dynamic> member, String field) {
    final profile = member['profile'];
    final nested = profile is Map<String, dynamic> ? profile[field] : null;
    if (nested is String && nested.isNotEmpty) return nested;
    final topLevel = member[field];
    return topLevel is String ? topLevel : '';
  }

  Future<List<String>> _fetchAllMemberIds(String path) async {
    final members = await _fetchAllMembers(path);
    return [
      for (final member in members)
        if ((member['id'] as String? ?? '').isNotEmpty) member['id'] as String,
    ];
  }

  Future<List<Map<String, dynamic>>> _fetchAllMembers(String path) async {
    final members = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxMemberPages; page++) {
      final response = await apiBaseService.get<Map<String, dynamic>>(
        path: path,
        queryParameters: {'page': page, 'limit': memberPageSize},
      );
      final data = response.data['data'] as List?;
      if (data == null || data.isEmpty) return members;
      members.addAll(data.cast<Map<String, dynamic>>());
      if (data.length < memberPageSize) return members;
    }
    // Every page was full, so the list may go on. Fail rather than act on
    // part of it.
    throw ApiFailure(
      message: 'Too many members to load. Please try again later.',
      path: path,
    );
  }
}
