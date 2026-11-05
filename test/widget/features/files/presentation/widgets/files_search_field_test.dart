import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

const _workspaceA = Workspace(id: 'org-a', name: 'Workspace A', avatar: '');
const _workspaceB = Workspace(id: 'org-b', name: 'Workspace B', avatar: '');

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() =>
      const WorkspaceState(selectedWorkspace: _workspaceA);

  void select(Workspace workspace) =>
      state = WorkspaceState(selectedWorkspace: workspace);
}

void main() {
  late ProviderContainer container;

  Future<void> pumpToolbar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container = ProviderContainer(
      overrides: [workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestMaterialApp(const Scaffold(body: FilesToolbar())),
      ),
    );
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  String search() => container.read(filesProvider).search;

  Future<void> switchWorkspace(WidgetTester tester) async {
    (container.read(workspaceProvider.notifier) as _FakeWorkspaceNotifier)
        .select(_workspaceB);
    await tester.pump();
  }

  testWidgets('clears the box when a workspace switch resets the search', (
    tester,
  ) async {
    await pumpToolbar(tester);
    await tester.enterText(find.byType(TextField), 'budget');
    await tester.pump(const Duration(milliseconds: 400));
    expect(search(), 'budget');

    await switchWorkspace(tester);

    expect(search(), isEmpty);
    expect(fieldText(tester), isEmpty);
  });

  testWidgets('drops typing still waiting to be reported when reset', (
    tester,
  ) async {
    await pumpToolbar(tester);
    await tester.enterText(find.byType(TextField), 'budget');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'budget plan');

    await switchWorkspace(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(search(), isEmpty);
    expect(fieldText(tester), isEmpty);
  });

  testWidgets('keeps what is being typed when an earlier search lands', (
    tester,
  ) async {
    await pumpToolbar(tester);
    await tester.enterText(find.byType(TextField), 'bud');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'budget');
    await tester.pump();

    expect(search(), 'bud');
    expect(fieldText(tester), 'budget');

    await tester.pump(const Duration(milliseconds: 400));
    expect(search(), 'budget');
    expect(fieldText(tester), 'budget');
  });

  testWidgets('shows the current search when the box is created', (
    tester,
  ) async {
    await pumpToolbar(tester);
    container.read(filesProvider.notifier).setSearch('budget');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestMaterialApp(const Scaffold(body: FilesToolbar())),
      ),
    );

    expect(fieldText(tester), 'budget');
  });
}
