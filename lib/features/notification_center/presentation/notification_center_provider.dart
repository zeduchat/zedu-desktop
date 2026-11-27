import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class NotificationCenterState {
  const NotificationCenterState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.loadMoreError,
    this.selectedId,
    this.readIds = const {},
    this.seenAt,
    this.page = 0,
  });

  final List<AppNotification> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  /// Why loading the next page failed; the list shows it with a Retry.
  final String? loadMoreError;
  final String? selectedId;

  /// Ids read on this device (zedu-fe keeps the same set).
  final Set<String> readIds;

  /// Notifications sent before this count as read.
  final DateTime? seenAt;

  /// The last feed page loaded; 0 before the first.
  final int page;

  bool isUnread(AppNotification item) {
    if (item.serverRead || readIds.contains(item.id)) return false;
    final seen = seenAt;
    final sent = item.sentAt;
    if (seen != null && sent != null && !sent.isAfter(seen)) return false;
    return true;
  }

  int get unreadCount => items.where(isUnread).length;

  AppNotification? get selected {
    for (final item in items) {
      if (item.id == selectedId) return item;
    }
    return null;
  }

  NotificationCenterState copyWith({
    List<AppNotification>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
    String? loadMoreError,
    bool clearLoadMoreError = false,
    String? selectedId,
    bool clearSelection = false,
    Set<String>? readIds,
    DateTime? seenAt,
    int? page,
  }) => NotificationCenterState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : error ?? this.error,
    loadMoreError: clearLoadMoreError
        ? null
        : loadMoreError ?? this.loadMoreError,
    selectedId: clearSelection ? null : selectedId ?? this.selectedId,
    readIds: readIds ?? this.readIds,
    seenAt: seenAt ?? this.seenAt,
    page: page ?? this.page,
  );
}

/// The Notifications page's list and the bell's unread count. Loads the first
/// page for the signed-in user's selected workspace, and refreshes it every
/// minute so the bell badge stays current, as zedu-fe syncs its badge.
class NotificationCenterNotifier extends Notifier<NotificationCenterState> {
  static const refreshInterval = Duration(minutes: 1);

  String? _userId;
  String? _orgId;
  int _generation = 0;
  Timer? _timer;

  @override
  NotificationCenterState build() {
    _userId = _watchOrNull(
      () => ref.watch(authNotifierProvider.select((s) => s.user?.id)),
    );
    // Only signed in is there a workspace to load notifications for; this
    // also keeps the workspaces from loading where nobody is.
    // Without the app's services (widget tests that show the rail) there is
    // nothing to load, and the workspaces must not start loading either.
    _orgId =
        _userId == null ||
            !locator.isRegistered<ApiBaseService>() ||
            !locator.isRegistered<SecureStorageService>()
        ? null
        : _watchOrNull(
            () => ref.watch(
              workspaceProvider.select((s) => s.selectedWorkspace?.id),
            ),
          );
    _generation++;
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (_userId == null || _orgId == null) {
      return const NotificationCenterState();
    }
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
    Future.microtask(() {
      if (ref.mounted) refresh();
    });
    return const NotificationCenterState(isLoading: true);
  }

  /// Reads a session value, or null where the session can't be set up
  /// (isolated widget tests, where the app's services aren't registered).
  String? _watchOrNull(String? Function() read) {
    try {
      return read();
    } on Object {
      return null;
    }
  }

  /// Reloads the first page and merges it into what is already loaded: new
  /// notifications go on top and changed ones are updated, while later pages
  /// and the selected notification stay (they were dropped before).
  Future<void> refresh() async {
    final userId = _userId;
    final orgId = _orgId;
    if (userId == null || orgId == null) return;
    final generation = _generation;
    if (state.items.isEmpty) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final repository = ref.read(notificationCenterRepositoryProvider);
      final readIds = await repository.readIds(userId, orgId);
      var seenAt = await repository.seenAt(userId, orgId);
      // First load on this device: what's already there counts as seen.
      seenAt ??= await repository.markSeenNow(userId, orgId);
      final page = await repository.load(orgId);
      if (!ref.mounted || generation != _generation) return;
      final merged = mergeFirstPage(page.items, state.items);
      final keepsLaterPages = state.page > 1;
      state = state.copyWith(
        items: merged,
        hasMore: keepsLaterPages ? state.hasMore : page.hasMore,
        page: keepsLaterPages ? state.page : 1,
        // Union, so an item marked read while this refresh was loading stays
        // read even if its save hadn't landed yet.
        readIds: {...readIds, ...state.readIds},
        seenAt: seenAt,
        isLoading: false,
        clearError: true,
        clearSelection: !merged.any((i) => i.id == state.selectedId),
      );
    } on Object catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        error: error is ApiFailure
            ? error.friendlyMessage
            : 'Could not load notifications. Please try again.',
      );
    }
  }

  /// Loads the next page, for the list's infinite scroll.
  Future<void> loadMore() async {
    final orgId = _orgId;
    if (orgId == null ||
        !state.hasMore ||
        state.isLoading ||
        state.isLoadingMore) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final page = await ref
          .read(notificationCenterRepositoryProvider)
          .load(orgId, page: state.page + 1);
      if (!ref.mounted || generation != _generation) return;
      final known = state.items.map((i) => i.id).toSet();
      state = state.copyWith(
        items: [
          ...state.items,
          ...page.items.where((i) => !known.contains(i.id)),
        ],
        hasMore: page.hasMore,
        page: state.page + 1,
        isLoadingMore: false,
      );
    } on Object catch (error) {
      if (!ref.mounted || generation != _generation) return;
      // Not the end of the list: keep hasMore so Retry can load it again.
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreError: error is ApiFailure
            ? error.friendlyMessage
            : 'Could not load more notifications.',
      );
    }
  }

  /// Shows [item] in the detail pane and marks it read: on the server
  /// (`PUT /users/onesignal-notifications/{id}/read`), so Zedu web and other
  /// devices clear it too, and in the local set straight away, which also
  /// covers a failed or offline request.
  Future<void> select(AppNotification item) async {
    state = state.copyWith(selectedId: item.id);
    if (!state.isUnread(item)) return;
    final readIds = {...state.readIds, item.id};
    state = state.copyWith(readIds: readIds);
    final userId = _userId;
    final orgId = _orgId;
    if (userId == null || orgId == null) return;
    final repository = ref.read(notificationCenterRepositoryProvider);
    try {
      await repository.saveReadIds(userId, orgId, readIds);
    } on Object catch (error) {
      AppLogger.w(
        'Could not save read notifications: $error',
        tag: 'NotificationCenter',
      );
    }
    try {
      await repository.markRead(item.id);
    } on Object catch (error) {
      AppLogger.w(
        'Could not mark notification ${item.id} read on the server: $error',
        tag: 'NotificationCenter',
      );
    }
  }

  void clearSelection() => state = state.copyWith(clearSelection: true);
}

/// [firstPage] merged into [loaded]: notifications only in [firstPage] go on
/// top, ones in both take [firstPage]'s newer copy in its place, and the rest
/// of [loaded] (later pages) keeps its order below.
@visibleForTesting
List<AppNotification> mergeFirstPage(
  List<AppNotification> firstPage,
  List<AppNotification> loaded,
) {
  final fresh = {for (final item in firstPage) item.id: item};
  final loadedIds = loaded.map((i) => i.id).toSet();
  return [
    ...firstPage.where((i) => !loadedIds.contains(i.id)),
    for (final item in loaded) fresh[item.id] ?? item,
  ];
}

final notificationCenterProvider =
    NotifierProvider<NotificationCenterNotifier, NotificationCenterState>(
      NotificationCenterNotifier.new,
    );

/// How many notifications are unread, for the rail bell's badge.
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(notificationCenterProvider).unreadCount,
);
