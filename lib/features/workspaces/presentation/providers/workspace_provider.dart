import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  static const loadErrorMessage = "Couldn't load your organisations";
  static const switchErrorMessage =
      "Couldn't switch organisation. Please try again.";

  int _latestSwitchId = 0;
  bool _isSwitchPending = false;
  Future<void>? _switchInFlight;

  /// The organisation the server's current access token is for, once a switch
  /// has changed it; null until then.
  String? _serverOrgId;

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
      final workspaces = await ref
          .read(workspaceRemoteDataSourceProvider)
          .getOrganisations();

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
        membersCount: 1351,
      ),
      const Workspace(
        id: '2',
        name: 'TeamFlow Collective',
        avatar: '',
        unreadCount: 15,
        membersCount: 42,
      ),
      const Workspace(
        id: '3',
        name: 'Coffee & Code House',
        avatar: '',
        unreadCount: 0,
        membersCount: 12,
      ),
      const Workspace(
        id: '4',
        name: 'ConnectHub',
        avatar: '',
        unreadCount: 3,
        membersCount: 89,
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

  /// Makes [workspace] the current organisation and returns an error message
  /// when that fails, or null otherwise. The server reads the organisation
  /// from the access token, so it has to hand out a new token for the switch.
  Future<String?> switchWorkspace(Workspace workspace) async {
    // The newest selection wins: any switch still waiting below gives up.
    final switchId = ++_latestSwitchId;

    // The server revokes the token it is called with, so a second call made
    // before the first ends would send a token that no longer works.
    while (_switchInFlight != null) {
      await _switchInFlight;
    }
    if (switchId != _latestSwitchId) return null;

    final serverOrgId = _serverOrgId;
    if (state.selectedWorkspace?.id == workspace.id &&
        (serverOrgId == null || serverOrgId == workspace.id)) {
      if (_isSwitchPending) {
        _isSwitchPending = false;
        state = state.copyWith(isLoading: false);
      }
      return null;
    }

    _isSwitchPending = true;
    state = state.copyWith(isLoading: true);
    final inFlight = Completer<void>();
    _switchInFlight = inFlight.future;

    try {
      if (locator<AppConfig>().usesMockData) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      } else {
        final response = await locator<ApiBaseService>()
            .put<Map<String, dynamic>>(
              path: '/users/switch-org',
              data: {'current_org': workspace.id},
            );
        final data = response.data['data'];
        final token = data is Map ? data['access_token'] : null;
        if (token is! String || token.isEmpty) {
          throw const FormatException('switch-org returned no access token');
        }
        await locator<SecureStorageService>().replaceAccessToken(token);
      }
      _serverOrgId = workspace.id;
      if (switchId != _latestSwitchId) return null;

      // Providers that watch the selection reload after this, with the new
      // token already in place.
      _isSwitchPending = false;
      state = state.copyWith(selectedWorkspace: workspace, isLoading: false);
      return null;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to switch organisation',
        tag: 'WorkspaceNotifier',
        error: e,
        stackTrace: stackTrace,
      );
      if (switchId != _latestSwitchId) return null;
      _isSwitchPending = false;
      state = state.copyWith(isLoading: false);
      return switchErrorMessage;
    } finally {
      _switchInFlight = null;
      inFlight.complete();
    }
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
}

final workspaceProvider = NotifierProvider<WorkspaceNotifier, WorkspaceState>(
  WorkspaceNotifier.new,
);
