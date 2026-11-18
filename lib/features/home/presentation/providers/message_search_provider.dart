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
    this.page = 0,
    this.totalPages = 0,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final String text;
  final MessageSearchFilters filters;
  final AsyncValue<List<SearchResultModel>> results;

  /// The API page the shown results end on, and how many pages there are.
  final int page;
  final int totalPages;

  /// True while the next page is being fetched.
  final bool isLoadingMore;

  /// The last "load more" failed; the results already shown are kept.
  final bool loadMoreFailed;

  /// A search runs once there are words to look for or a filter to narrow by.
  bool get canSearch => text.trim().isNotEmpty || filters.activeCount > 0;

  /// More matches exist on a later API page.
  bool get hasMore => totalPages > page;

  MessageSearchState copyWith({
    String? text,
    MessageSearchFilters? filters,
    AsyncValue<List<SearchResultModel>>? results,
    int? page,
    int? totalPages,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) => MessageSearchState(
    text: text ?? this.text,
    filters: filters ?? this.filters,
    results: results ?? this.results,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

class MessageSearchNotifier extends Notifier<MessageSearchState> {
  /// Each search gets a number; a reply to an older one is dropped, so slow
  /// answers never overwrite newer results.
  int _generation = 0;

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

  /// Runs the search for the current words and filters, from the first page.
  Future<void> search() async {
    final generation = ++_generation;
    if (!state.canSearch) {
      state = state.copyWith(
        results: const AsyncData([]),
        page: 0,
        totalPages: 0,
        isLoadingMore: false,
      );
      return;
    }
    final query = buildMessageSearchQuery(
      state.text,
      state.filters,
      now: now(),
    );
    state = state.copyWith(results: const AsyncLoading(), isLoadingMore: false);
    try {
      final page = await ref
          .read(messageSearchServiceProvider)
          .search(orgId: ref.read(creditsOrgIdProvider), query: query);
      if (generation != _generation) return;
      state = state.copyWith(
        results: AsyncData(page.results),
        page: page.currentPage,
        totalPages: page.totalPages,
      );
    } catch (error, stack) {
      if (generation != _generation) return;
      state = state.copyWith(
        results: AsyncError(error, stack),
        page: 0,
        totalPages: 0,
      );
    }
  }

  /// Appends the next API page of results, keeping the ones already shown.
  ///
  /// The same words and filters are used, so the pages belong together; a new
  /// search bumps the generation and a late answer is dropped.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;

    final current = switch (state.results) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (current == null) return;

    final generation = ++_generation;
    final query = buildMessageSearchQuery(
      state.text,
      state.filters,
      now: now(),
    );

    state = state.copyWith(isLoadingMore: true, loadMoreFailed: false);

    try {
      final page = await ref
          .read(messageSearchServiceProvider)
          .search(
            orgId: ref.read(creditsOrgIdProvider),
            query: query,
            page: state.page + 1,
          );
      if (generation != _generation) return;

      final seen = current.map((result) => result.id).toSet();
      state = state.copyWith(
        results: AsyncData([
          ...current,
          ...page.results.where((result) => seen.add(result.id)),
        ]),
        page: page.currentPage,
        totalPages: page.totalPages,
        isLoadingMore: false,
      );
    } catch (_) {
      if (generation != _generation) return;
      // Keep what is already shown; the footer offers another try.
      state = state.copyWith(isLoadingMore: false, loadMoreFailed: true);
    }
  }
}

final messageSearchProvider =
    NotifierProvider.autoDispose<MessageSearchNotifier, MessageSearchState>(
      MessageSearchNotifier.new,
    );
