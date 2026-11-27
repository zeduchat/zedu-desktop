import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The loaded part of a channel's history.
class ChannelHistoryState {
  const ChannelHistoryState({
    required this.messages,
    this.nextPage = 2,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  /// Every loaded message, newest first.
  final List<ChannelMessage> messages;

  /// The page [ChannelHistoryNotifier.loadMore] asks for next.
  final int nextPage;

  /// False only once the last page has been loaded.
  final bool hasMore;

  final bool isLoadingMore;

  /// Set when the last request for an older page failed. Cleared by the next
  /// [ChannelHistoryNotifier.loadMore], which doubles as the retry.
  final Object? loadMoreError;

  ChannelHistoryState copyWith({
    List<ChannelMessage>? messages,
    int? nextPage,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) => ChannelHistoryState(
    messages: messages ?? this.messages,
    nextPage: nextPage ?? this.nextPage,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
  );
}

/// A channel's history: the newest page first, older pages on [loadMore].
class ChannelHistoryNotifier extends AsyncNotifier<ChannelHistoryState> {
  ChannelHistoryNotifier(this.channelId);

  final String channelId;

  @override
  Future<ChannelHistoryState> build() async {
    final page = await _fetchPage(ref.watch(channelRepositoryProvider), 1);
    return ChannelHistoryState(
      messages: _merge(const [], page.messages),
      hasMore: page.hasMore,
    );
  }

  /// Loads the next older page and appends it. Does nothing while a page is
  /// loading or after the last one. After a failure, call it again to retry.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    final loading = current.copyWith(
      isLoadingMore: true,
      clearLoadMoreError: true,
    );
    state = AsyncData(loading);

    // The history can be reloaded (a sent message invalidates it) while this
    // request is out; a late answer must not overwrite the fresh state.
    bool isStale() => !ref.mounted || !identical(state.value, loading);

    try {
      final page = await _fetchPage(
        ref.read(channelRepositoryProvider),
        current.nextPage,
      );
      if (isStale()) return;
      final merged = _merge(current.messages, page.messages);
      final added = merged.length - current.messages.length;
      state = AsyncData(
        current.copyWith(
          messages: merged,
          nextPage: current.nextPage + 1,
          // A page with nothing new ends the list, so a backend that ignores
          // `page` cannot keep this loading the same messages.
          hasMore: page.hasMore && added > 0,
          isLoadingMore: false,
          // `current` still holds the error of a failed attempt this retry
          // is answering.
          clearLoadMoreError: true,
        ),
      );
    } catch (error) {
      if (isStale()) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: error),
      );
    }
  }

  /// Shows the saved edit of the message with [threadId] as [text] straight
  /// away. A refetch can still return the old text for a while after the
  /// edit (Ziki #12383), so the loaded message is patched in place instead.
  void applyEdit(String threadId, String text) {
    final current = state.value;
    if (current == null) return;
    if (!current.messages.any((m) => m.threadId == threadId)) return;
    final messages = [
      for (final m in current.messages)
        if (m.threadId == threadId)
          ChannelMessage(
            id: m.id,
            senderName: m.senderName,
            text: text,
            rawContent: text,
            avatarUrl: m.avatarUrl,
            createdAt: m.createdAt,
            status: m.status,
            media: m.media,
            threadId: m.threadId,
            userId: m.userId,
            reactions: m.reactions,
          )
        else
          m,
    ];
    state = AsyncData(current.copyWith(messages: messages));
  }

  Future<ChannelMessagePage> _fetchPage(
    ChannelRepository repository,
    int page,
  ) async {
    final result = await repository.fetchChannelMessages(channelId, page: page);
    return switch (result) {
      Success<ChannelMessagePage>(:final value) => value,
      Failure<ChannelMessagePage>(:final error) => throw error,
    };
  }

  /// [existing] followed by the messages of [incoming] it does not hold yet,
  /// in order. A new message shifts the pages, so a page can repeat the tail
  /// of the one before it.
  List<ChannelMessage> _merge(
    List<ChannelMessage> existing,
    List<ChannelMessage> incoming,
  ) {
    final seen = existing.map((m) => m.dedupeKey).toSet();
    return [
      ...existing,
      for (final message in incoming)
        if (seen.add(message.dedupeKey)) message,
    ];
  }
}

/// A channel's history, newest first.
final channelHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<ChannelHistoryNotifier, ChannelHistoryState, String>(
      ChannelHistoryNotifier.new,
    );

/// The people in a channel, for @mention suggestions in its composer.
final channelMembersProvider = FutureProvider.autoDispose
    .family<List<DmParticipant>, String>((ref, channelId) async {
      final result = await ref
          .watch(channelRepositoryProvider)
          .fetchChannelMembers(channelId);
      return switch (result) {
        Success<List<DmParticipant>>(:final value) => value,
        Failure<List<DmParticipant>>(:final error) => throw error,
      };
    });

/// The usernames of everyone who reacted with a given reaction on a message.
final reactionUsersProvider = FutureProvider.autoDispose
    .family<List<String>, ({String reactionId, String threadId})>((
      ref,
      key,
    ) async {
      final result = await ref
          .watch(channelRepositoryProvider)
          .fetchReactionUsers(
            reactionId: key.reactionId,
            threadId: key.threadId,
          );
      return switch (result) {
        Success<List<String>>(:final value) => value,
        Failure<List<String>>(:final error) => throw error,
      };
    });
