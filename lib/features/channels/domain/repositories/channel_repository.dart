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

  /// Starts exporting the channel's history (or returns the running export).
  Future<Result<ChannelExport>> startChannelExport(String channelId);

  /// The latest export of the channel's history for the current user.
  Future<Result<ChannelExport>> fetchChannelExportStatus(String channelId);
  Future<Result<List<String>>> fetchOrganisationMemberIds(String orgId);
  Future<Result<List<String>>> fetchChannelMemberIds(String channelId);
  Future<Result<List<DmParticipant>>> fetchChannelMembers(String channelId);
  Future<Result<void>> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  });

  /// One page of a channel's messages, newest first. Page 1 is the newest.
  Future<Result<ChannelMessagePage>> fetchChannelMessages(
    String channelId, {
    int page = 1,
  });
  Future<Result<void>> editChannelMessage({
    required String channelId,
    required String threadId,
    required String content,
  });
  Future<Result<void>> deleteChannelMessage({
    required String channelId,
    required String threadId,
  });

  /// Usernames of the users who reacted with [reactionId] on [threadId].
  Future<Result<List<String>>> fetchReactionUsers({
    required String reactionId,
    required String threadId,
  });

  /// Adds the current user's [emoji] reaction to [threadId], or removes it
  /// if they have already reacted. Returns whether the user reacted now.
  Future<Result<bool>> toggleReaction({
    required String channelId,
    required String threadId,
    required String emoji,
  });
}
