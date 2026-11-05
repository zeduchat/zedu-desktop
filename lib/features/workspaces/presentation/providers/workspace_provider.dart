import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  static const loadErrorMessage = "Couldn't load your organisations";

  int _latestSwitchId = 0;
  bool _isSwitchPending = false;

  @override
  WorkspaceState build() {
    Future.microtask(fetchWorkspaces);
    return const WorkspaceState(isLoading: true);
  }

  Future<void> fetchWorkspaces() async {
    if (locator<AppConfig>().usesMockData) {
      state = _mockState();
      return;
    }

    state = WorkspaceState(
      workspaces: state.workspaces,
      selectedWorkspace: state.selectedWorkspace,
      isLoading: true,
    );
    try {
      final api = locator<ApiBaseService>();
      final response = await api.get<Map<String, dynamic>>(
        path: '/users/organisations',
      );
      final data = response.data['data'] as List<dynamic>? ?? [];

      final List<Workspace> workspaces = [];
      for (var item in data) {
        if (item is Map<String, dynamic>) {
          final rawId = item['id'];
          final id = rawId is String
              ? rawId.trim()
              : (rawId?.toString().trim() ?? '');
          if (id.isEmpty) {
            // Without an id the workspace cannot be selected or addressed.
            // Skipping it is better than collapsing every id-less
            // organisation onto one shared workspace id.
            AppLogger.w(
              'Skipping organisation without an id',
              tag: 'WorkspaceNotifier',
            );
            continue;
          }
          workspaces.add(
            Workspace(
              id: id,
              name: item['name'] as String? ?? 'Workspace',
              avatar: item['logo_url'] as String? ?? '',
              channelsCount: (item['channels_count'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }

      // Keep the current selection if it's still in the list (e.g. an org
      // created while this request was in flight).
      final previousId = state.selectedWorkspace?.id;
      final selected = workspaces.isEmpty
          ? null
          : workspaces.firstWhere(
              (ws) => ws.id == previousId,
              orElse: () => workspaces.first,
            );

      state = WorkspaceState(
        workspaces: workspaces,
        selectedWorkspace: selected,
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to load organisations',
        tag: 'WorkspaceNotifier',
        error: e,
        stackTrace: stackTrace,
      );
      // A failed refresh keeps what's already loaded.
      state = WorkspaceState(
        workspaces: state.workspaces,
        selectedWorkspace: state.selectedWorkspace,
        errorMessage: loadErrorMessage,
      );
    }
  }

  // Demo organisations, only used when the app runs with USE_MOCK_DATA.
  WorkspaceState _mockState() {
    final workspaces = [
      const Workspace(
        id: '1',
        name: 'HNG Workspace',
        avatar: '',
        unreadCount: 1351,
        channelsCount: 1351,
      ),
      const Workspace(
        id: '2',
        name: 'TeamFlow Collective',
        avatar: '',
        unreadCount: 15,
        channelsCount: 42,
      ),
      const Workspace(
        id: '3',
        name: 'Coffee & Code House',
        avatar: '',
        unreadCount: 0,
        channelsCount: 12,
      ),
      const Workspace(
        id: '4',
        name: 'ConnectHub',
        avatar: '',
        unreadCount: 3,
        channelsCount: 89,
      ),
    ];

    return WorkspaceState(
      workspaces: workspaces,
      selectedWorkspace: workspaces.first,
    );
  }

  void addWorkspace(Workspace workspace, {bool switchTo = true}) {
    final current = state.workspaces;
    if (current.any((w) => w.id == workspace.id)) return;
    final updated = [...current, workspace];
    state = state.copyWith(
      workspaces: updated,
      selectedWorkspace: switchTo ? workspace : state.selectedWorkspace,
    );
  }

  /// Keeps the name in the list and the selection in step with a rename.
  void renameWorkspace(String id, String name) {
    Workspace rename(Workspace w) => w.id == id ? w.copyWith(name: name) : w;
    final selected = state.selectedWorkspace;
    state = state.copyWith(
      workspaces: state.workspaces.map(rename).toList(),
      selectedWorkspace: selected == null ? null : rename(selected),
    );
  }

  Future<void> switchWorkspace(Workspace workspace) async {
    // The newest selection wins: any switch still waiting below gives up.
    final switchId = ++_latestSwitchId;

    if (state.selectedWorkspace?.id == workspace.id) {
      if (_isSwitchPending) {
        _isSwitchPending = false;
        state = state.copyWith(isLoading: false);
      }
      return;
    }

    _isSwitchPending = true;
    state = state.copyWith(isLoading: true);

    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (switchId != _latestSwitchId) return;

    _isSwitchPending = false;
    state = state.copyWith(selectedWorkspace: workspace, isLoading: false);
  }

  void removeWorkspace(String id) {
    final updatedWorkspaces = state.workspaces
        .where((w) => w.id != id)
        .toList();
    Workspace? nextSelected = state.selectedWorkspace;
    if (state.selectedWorkspace?.id == id) {
      nextSelected = updatedWorkspaces.isNotEmpty
          ? updatedWorkspaces.first
          : null;
    }
    state = state.copyWith(
      workspaces: updatedWorkspaces,
      selectedWorkspace: nextSelected,
      clearSelectedWorkspace: nextSelected == null,
    );
  }

  /// A DM belongs to one workspace. When the selected workspace really changes
  /// (or goes away), the DM that was open there must not stay as the composer's
  /// target, so the selection is cleared. The first workspace to load, and a
  /// switch to the workspace that is already open, keep it.
  @override
  bool updateShouldNotify(WorkspaceState previous, WorkspaceState next) {
    final before = previous.selectedWorkspace?.id;
    if (before != null && before != next.selectedWorkspace?.id) {
      ref.invalidate(selectedDmProvider);
    }
    return super.updateShouldNotify(previous, next);
  }
}

final workspaceProvider = NotifierProvider<WorkspaceNotifier, WorkspaceState>(
  WorkspaceNotifier.new,
);
