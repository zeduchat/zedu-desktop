import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );

  void switchTo(String id) {
    state = WorkspaceState(
      selectedWorkspace: Workspace(id: id, name: 'Workspace $id', avatar: ''),
    );
  }
}

final _dm = DmConversation(
  channelId: 'dm-1',
  username: 'ada',
  participantId: 'p-1',
  previewMessage: 'hi',
  unreadCount: 0,
);

void main() {
  late ProviderContainer container;

  _FakeWorkspaceNotifier workspace() =>
      container.read(workspaceProvider.notifier) as _FakeWorkspaceNotifier;

  setUp(() {
    container = ProviderContainer(
      overrides: [workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new)],
    );
    addTearDown(container.dispose);
    // Keep the selection alive, as the app does while the home screen is open.
    container.listen(selectedDmProvider, (_, _) {});
  });

  test('switching to another workspace clears the selected DM', () {
    container.read(selectedDmProvider.notifier).select(_dm);
    expect(container.read(selectedDmProvider)?.channelId, 'dm-1');

    workspace().switchTo('org-2');

    expect(container.read(selectedDmProvider), isNull);
  });

  test('choosing the workspace that is already open keeps the DM', () {
    container.read(selectedDmProvider.notifier).select(_dm);

    workspace().switchTo('org-1');

    expect(container.read(selectedDmProvider)?.channelId, 'dm-1');
  });

  test('a DM chosen after the switch is selected normally', () {
    workspace().switchTo('org-2');

    container.read(selectedDmProvider.notifier).select(_dm);

    expect(container.read(selectedDmProvider)?.channelId, 'dm-1');
  });
}
