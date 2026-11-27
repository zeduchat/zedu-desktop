import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final messageSearchServiceProvider = Provider<MessageSearchService>(
  (ref) => MessageSearchService(locator<ApiBaseService>()),
);

/// What the Search messages dialog shows (#2825): the typed words, the
/// filters that are on, and the results of the last search.
class MessageSearchState {
  const MessageSearchState({
    this.text = '',
    this.filters = MessageSearchFilters.none,
    this.results = const AsyncData(<SearchResultModel>[]),
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final String text;
  final MessageSearchFilters filters;
  final AsyncValue<List<SearchResultModel>> results;

  /// Whether the server has another page of results for this search.
  final bool hasMore;

  /// Whether the next page is being fetched.
  final bool isLoadingMore;

  /// Whether fetching the next page failed; the results so far stay shown.
  final bool loadMoreFailed;

  /// A search runs once there are words to look for or a filter to narrow by.
  bool get canSearch => text.trim().isNotEmpty || filters.activeCount > 0;

  MessageSearchState copyWith({
    String? text,
    MessageSearchFilters? filters,
    AsyncValue<List<SearchResultModel>>? results,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) => MessageSearchState(
    text: text ?? this.text,
    filters: filters ?? this.filters,
    results: results ?? this.results,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

class MessageSearchNotifier extends Notifier<MessageSearchState> {
  /// Each search gets a number; a reply to an older one is dropped, so slow
  /// answers never overwrite newer results.
  int _generation = 0;

  /// The last page loaded for the current search.
  int _page = 1;

  /// The query the current results are for, so later pages ask for the same.
  String _query = '';

  /// The clock the date filters count from; tests replace it.
  DateTime Function() now = DateTime.now;

  @override
  MessageSearchState build() {
    // Results from one workspace mean nothing in another.
    ref.watch(creditsOrgIdProvider);
    return const MessageSearchState();
  }

  void setText(String text) {
    state = state.copyWith(text: text);
    search();
  }

  void setFilters(MessageSearchFilters filters) {
    state = state.copyWith(filters: filters);
    search();
  }

  void clearFilters() => setFilters(MessageSearchFilters.none);

  /// Runs the search for the current words and filters.
  Future<void> search() async {
    final generation = ++_generation;
    state = state.copyWith(
      hasMore: false,
      isLoadingMore: false,
      loadMoreFailed: false,
    );
    if (!state.canSearch) {
      state = state.copyWith(results: const AsyncData([]));
      return;
    }
    final query = buildMessageSearchQuery(
      state.text,
      state.filters,
      now: now(),
    );
    _query = query;
    _page = 1;
    state = state.copyWith(results: const AsyncLoading());
    try {
      final page = await ref
          .read(messageSearchServiceProvider)
          .search(orgId: ref.read(creditsOrgIdProvider), query: query);
      if (generation != _generation) return;
      state = state.copyWith(
        results: AsyncData(page.results),
        hasMore: page.hasMore,
      );
    } catch (error, stack) {
      if (generation != _generation) return;
      state = state.copyWith(results: AsyncError(error, stack));
    }
  }

  /// Adds the next page of results for the current search, newest first.
  /// Does nothing while a page is loading or when there are no more.
  Future<void> loadMore() async {
    final current = state.results.value;
    if (current == null || state.results.isLoading) return;
    if (!state.hasMore || state.isLoadingMore) return;
    final generation = _generation;
    final next = _page + 1;
    state = state.copyWith(isLoadingMore: true, loadMoreFailed: false);
    try {
      final page = await ref
          .read(messageSearchServiceProvider)
          .search(
            orgId: ref.read(creditsOrgIdProvider),
            query: _query,
            page: next,
          );
      if (generation != _generation) return;
      // Pages can overlap when new messages arrive between requests.
      final seen = {for (final result in current) result.id};
      final merged = [
        ...current,
        ...page.results.where((result) => seen.add(result.id)),
      ]..sort(compareMessageSearchResults);
      _page = next;
      state = state.copyWith(
        results: AsyncData(merged),
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      if (generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreFailed: true);
    }
  }
}

final messageSearchProvider =
    NotifierProvider.autoDispose<MessageSearchNotifier, MessageSearchState>(
      MessageSearchNotifier.new,
    );
