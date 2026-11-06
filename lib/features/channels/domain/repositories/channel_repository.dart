import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class ChannelRepository {
  Future<Result<List<Channel>>> fetchChannels(String orgId);
  Future<Result<Channel>> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  });
  Future<Result<void>> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  });
  Future<Result<void>> archiveChannel(String channelId, bool archived);
  Future<Result<List<Channel>>> fetchArchivedChannels(String orgId);

  /// Removes the current user from the channel.
  Future<Result<void>> leaveChannel(String channelId);
  Future<Result<void>> joinChannel(String channelId);

  /// Stars the channel for the current user, or unstars it if it is
  /// starred. Succeeds with whether it is starred now.
  Future<Result<bool>> toggleStarChannel({
    required String orgId,
    required String channelId,
  });
  Future<Result<List<String>>> fetchOrganisationMemberIds(String orgId);
  Future<Result<List<String>>> fetchChannelMemberIds(String channelId);
  Future<Result<List<DmParticipant>>> fetchChannelMembers(String channelId);
  Future<Result<void>> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  });

  /// The latest messages of a channel, newest first.
  Future<Result<List<ChannelMessage>>> fetchChannelMessages(String channelId);
  Future<Result<void>> editChannelMessage({
    required String channelId,
    required String threadId,
    required String content,
  });
  Future<Result<void>> deleteChannelMessage({
    required String channelId,
    required String threadId,
  });
}
