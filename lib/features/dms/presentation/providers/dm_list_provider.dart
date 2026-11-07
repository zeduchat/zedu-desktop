import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final currentOrgIdProvider = Provider<String>((ref) {
  final workspace = ref.watch(workspaceProvider).selectedWorkspace;
  return workspace?.id ?? '';
});

final dmListProvider =
    AsyncNotifierProvider<DmListNotifier, List<DmConversation>>(() {
      return DmListNotifier();
    });

class SelectedDmNotifier extends Notifier<DmConversation?> {
  @override
  DmConversation? build() {
    // A conversation belongs to the active workspace. Rebuild and clear the
    // selection when that workspace changes so it cannot remain the composer
    // target for a different workspace.
    ref.watch(currentOrgIdProvider);
    return null;
  }

  void select(DmConversation? conversation) {
    state = conversation;
  }
}

final selectedDmProvider =
    NotifierProvider<SelectedDmNotifier, DmConversation?>(
      SelectedDmNotifier.new,
    );

class DmConversationActions {
  final Set<String> pinnedIds;
  final Set<String> deletedIds;

  const DmConversationActions({
    this.pinnedIds = const {},
    this.deletedIds = const {},
  });

  DmConversationActions copyWith({
    Set<String>? pinnedIds,
    Set<String>? deletedIds,
  }) => DmConversationActions(
    pinnedIds: pinnedIds ?? this.pinnedIds,
    deletedIds: deletedIds ?? this.deletedIds,
  );
}

class DmConversationActionsNotifier extends Notifier<DmConversationActions> {
  /// Where this user's pins are remembered (null while signed out).
  String? _pinnedKey;

  @override
  DmConversationActions build() {
    // Rebuilt for each signed-in user, so one account never sees another's pins.
    final userId = dmPreferencesUserId(ref);
    _pinnedKey = userId == null || userId.isEmpty
        ? null
        : DmPreferencesStore.pinnedKey(userId);
    final key = _pinnedKey;
    if (key != null) _restorePinned(key);
    return const DmConversationActions();
  }

  Future<void> _restorePinned(String key) async {
    final saved = await ref.read(dmPreferencesStoreProvider).read(key);
    if (!ref.mounted || _pinnedKey != key || saved.isEmpty) return;
    // Keep anything pinned while the saved list was loading.
    state = state.copyWith(pinnedIds: {...saved, ...state.pinnedIds});
  }

  void togglePinned(String channelId) {
    final ids = Set<String>.from(state.pinnedIds);
    ids.contains(channelId) ? ids.remove(channelId) : ids.add(channelId);
    state = state.copyWith(pinnedIds: ids);
    final key = _pinnedKey;
    if (key != null) {
      unawaited(ref.read(dmPreferencesStoreProvider).write(key, ids));
    }
  }

  /// Deletes the conversation on the server, then hides it from the list
  /// until the next refresh drops it and discards its draft. Closes it only
  /// if it's still the open DM. Returns false if the request failed.
  Future<bool> delete(String channelId) async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return false;
    try {
      await ref
          .read(dmRepositoryProvider)
          .deleteConversation(orgId: orgId, channelId: channelId);
    } catch (_) {
      return false;
    }
    state = state.copyWith(deletedIds: {...state.deletedIds, channelId});
    ref.read(dmDraftStoreProvider).clear(channelId);
    if (ref.read(selectedDmProvider)?.channelId == channelId) {
      ref.read(selectedDmProvider.notifier).select(null);
    }
    return true;
  }
}

final dmConversationActionsProvider =
    NotifierProvider<DmConversationActionsNotifier, DmConversationActions>(
      DmConversationActionsNotifier.new,
    );

class DmListNotifier extends AsyncNotifier<List<DmConversation>> {
  int _currentPage = 1;
  bool _hasMore = true;

  /// Changes on every reload, so a page still in flight from before can be
  /// dropped.
  int _listVersion = 0;

  /// The list version of the "load more" call in flight, so a second scroll
  /// does not fetch and append the same page again.
  int? _loadingMoreVersion;

  bool get hasMore => _hasMore;

  @override
  Future<List<DmConversation>> build() async {
    final orgId = ref.watch(currentOrgIdProvider);
    _listVersion++;
    _loadingMoreVersion = null;
    if (orgId.isEmpty) return const [];

    _currentPage = 1;
    _hasMore = true;
    return _fetchPage(orgId, 1);
  }

  Future<List<DmConversation>> _fetchPage(String orgId, int page) async {
    final repository = ref.read(dmRepositoryProvider);
    final version = _listVersion;
    final results = await repository.getConversations(orgId: orgId, page: page);
    if (version == _listVersion && results.length < DmRepository.pageSize) {
      _hasMore = false;
    }

    final usesMockData =
        locator.isRegistered<AppConfig>() && locator<AppConfig>().usesMockData;
    if (usesMockData && results.isEmpty && page == 1) {
      return [
        DmConversation(
          channelId: 'mock-channel-id-123',
          username: 'Test User',
          participantId: 'mock-user-id',
          previewMessage:
              'This is a test conversation. Tap to test the composer.',
          unreadCount: 0,
        ),
      ];
    }

    return results;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    // A scroll can end several times before the first page arrives. Both calls
    // would fetch the same page and append it, showing every row twice.
    if (_loadingMoreVersion == _listVersion) return;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return;

    final current = state.value ?? [];
    final version = _listVersion;
    _loadingMoreVersion = version;
    // Only count the page once it has loaded, so a failed load is asked for
    // again on the next scroll instead of being skipped.
    final page = _currentPage + 1;
    try {
      final next = await _fetchPage(orgId, page);
      if (version != _listVersion) return;
      _currentPage = page;
      // A conversation can arrive between two page requests, shifting the
      // offset and returning one already listed. Keep the list unique too.
      final knownKeys = current.map((c) => c.conversationKey).toSet();
      state = AsyncValue.data([
        ...current,
        ...next.where((c) => knownKeys.add(c.conversationKey)),
      ]);
    } finally {
      if (_loadingMoreVersion == version) _loadingMoreVersion = null;
    }
  }

  Future<void> refresh() async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return;

    _listVersion++;
    _loadingMoreVersion = null;
    _currentPage = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPage(orgId, 1));
  }
}

class DmSearchResultsNotifier extends AsyncNotifier<List<DmConversation>> {
  DmSearchResultsNotifier(this.search);

  final String search;
  int _currentPage = 1;
  bool _hasMore = true;
  int _searchVersion = 0;

  bool get hasMore => _hasMore;

  @override
  Future<List<DmConversation>> build() async {
    final query = search.trim();
    if (query.isEmpty) return const [];
    final orgId = ref.watch(currentOrgIdProvider);
    if (orgId.isEmpty) return const [];

    _searchVersion++;
    _currentPage = 1;
    _hasMore = true;
    return _fetchPage(orgId, 1, query);
  }

  Future<List<DmConversation>> _fetchPage(
    String orgId,
    int page,
    String query,
  ) async {
    final repository = ref.read(dmRepositoryProvider);
    final version = _searchVersion;
    final results = await repository.getConversations(
      orgId: orgId,
      page: page,
      search: query,
    );
    if (version == _searchVersion && results.length < DmRepository.pageSize) {
      _hasMore = false;
    }
    return results;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final query = search.trim();
    if (query.isEmpty) return;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return;

    final current = state.value ?? [];
    final version = _searchVersion;
    final page = _currentPage + 1;
    final next = await _fetchPage(orgId, page, query);
    if (version != _searchVersion) return;
    _currentPage = page;
    state = AsyncValue.data([...current, ...next]);
  }

  Future<void> refresh() async {
    final query = search.trim();
    if (query.isEmpty) return;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return;

    _searchVersion++;
    _currentPage = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPage(orgId, 1, query));
  }
}

final dmSearchResultsProvider = AsyncNotifierProvider.autoDispose
    .family<DmSearchResultsNotifier, List<DmConversation>, String>(
      DmSearchResultsNotifier.new,
    );
