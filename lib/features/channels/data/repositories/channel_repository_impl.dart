import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ChannelRepositoryImpl implements ChannelRepository {
  final ChannelRemoteDataSource remoteDataSource;

  ChannelRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<List<Channel>>> fetchChannels(String orgId) async {
    try {
      final channels = await remoteDataSource.fetchChannels(orgId);
      return Success(channels);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<Channel>> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  }) async {
    try {
      final channel = await remoteDataSource.createChannel(
        name: name,
        description: description,
        orgId: orgId,
        username: username,
        isPrivate: isPrivate,
        topic: topic,
      );
      return Success(channel);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  }) async {
    try {
      await remoteDataSource.updateChannelTopicOrDescription(
        channelId: channelId,
        topic: topic,
        description: description,
      );
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> archiveChannel(String channelId, bool archived) async {
    try {
      await remoteDataSource.archiveChannel(channelId, archived);
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<Channel>>> fetchArchivedChannels(String orgId) async {
    try {
      return Success(await remoteDataSource.fetchArchivedChannels(orgId));
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> editChannelMessage({
    required String channelId,
    required String threadId,
    required String content,
  }) async {
    try {
      await remoteDataSource.editChannelMessage(
        channelId: channelId,
        threadId: threadId,
        content: content,
      );
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteChannelMessage({
    required String channelId,
    required String threadId,
  }) async {
    try {
      await remoteDataSource.deleteChannelMessage(
        channelId: channelId,
        threadId: threadId,
      );
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> leaveChannel(String channelId) async {
    try {
      await remoteDataSource.leaveChannel(channelId);
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> joinChannel(String channelId) async {
    try {
      await remoteDataSource.joinChannel(channelId);
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<bool>> toggleStarChannel({
    required String orgId,
    required String channelId,
  }) async {
    try {
      final isStarred = await remoteDataSource.toggleStarChannel(
        orgId: orgId,
        channelId: channelId,
      );
      return Success(isStarred);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<ChannelExport>> startChannelExport(String channelId) =>
      _export(() => remoteDataSource.startExport(channelId));

  @override
  Future<Result<ChannelExport>> fetchChannelExportStatus(String channelId) =>
      _export(() => remoteDataSource.fetchExportStatus(channelId));

  Future<Result<ChannelExport>> _export(
    Future<ChannelExport> Function() call,
  ) async {
    try {
      return Success(await call());
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<String>>> fetchOrganisationMemberIds(String orgId) async {
    try {
      final ids = await remoteDataSource.fetchOrganisationMemberIds(orgId);
      return Success(ids);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<String>>> fetchChannelMemberIds(String channelId) async {
    try {
      final ids = await remoteDataSource.fetchChannelMemberIds(channelId);
      return Success(ids);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<DmParticipant>>> fetchChannelMembers(
    String channelId,
  ) async {
    try {
      return Success(await remoteDataSource.fetchChannelMembers(channelId));
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  }) async {
    try {
      await remoteDataSource.addMembersToChannel(
        channelId: channelId,
        userIds: userIds,
      );
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<ChannelMessagePage>> fetchChannelMessages(
    String channelId, {
    int page = 1,
  }) async {
    try {
      return Success(
        await remoteDataSource.fetchChannelMessages(channelId, page: page),
      );
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<String>>> fetchReactionUsers({
    required String reactionId,
    required String threadId,
  }) async {
    try {
      return Success(
        await remoteDataSource.fetchReactionUsers(
          reactionId: reactionId,
          threadId: threadId,
        ),
      );
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<bool>> toggleReaction({
    required String channelId,
    required String threadId,
    required String emoji,
  }) async {
    try {
      return Success(
        await remoteDataSource.toggleReaction(
          channelId: channelId,
          threadId: threadId,
          emoji: emoji,
        ),
      );
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }
}
