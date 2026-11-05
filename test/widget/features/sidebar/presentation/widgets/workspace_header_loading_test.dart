import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

// Fake notifier that avoids GetIt/locator setup and records retries.
class FakeWorkspaceNotifier extends WorkspaceNotifier {
  FakeWorkspaceNotifier(this._initial);

  final WorkspaceState _initial;
  int fetchCalls = 0;

  @override
  WorkspaceState build() => _initial;

  @override
  Future<void> fetchWorkspaces() async {
    fetchCalls++;
  }
}

Widget buildHeaderUnderTest(FakeWorkspaceNotifier notifier) {
  return ProviderScope(
    overrides: [workspaceProvider.overrideWith(() => notifier)],
    child: buildTestMaterialApp(
      const Scaffold(body: WorkspaceSwitcherHeader()),
    ),
  );
}

void main() {
  group('WorkspaceSwitcherHeader', () {
    testWidgets('shows the selected organisation name', (tester) async {
      const workspace = Workspace(
        id: 'org-1',
        name: 'Riverside Academy',
        avatar: '',
      );
      await tester.pumpWidget(
        buildHeaderUnderTest(
          FakeWorkspaceNotifier(
            const WorkspaceState(
              workspaces: [workspace],
              selectedWorkspace: workspace,
            ),
          ),
        ),
      );

      expect(find.text('Riverside Academy'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('shows the error and retries when loading failed', (
      tester,
    ) async {
      final notifier = FakeWorkspaceNotifier(
        const WorkspaceState(errorMessage: WorkspaceNotifier.loadErrorMessage),
      );
      await tester.pumpWidget(buildHeaderUnderTest(notifier));

      expect(find.text(WorkspaceNotifier.loadErrorMessage), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(notifier.fetchCalls, 1);
    });

    testWidgets('offers to create an organisation when there is none', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: WorkspaceSwitcherHeader()),
          ),
          GoRoute(
            path: AppRouter.createOrganization,
            builder: (_, _) => const Text('create organization page'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceProvider.overrideWith(
              () => FakeWorkspaceNotifier(const WorkspaceState()),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No organization'), findsOneWidget);

      await tester.tap(find.text('Create one'));
      await tester.pumpAndSettle();

      expect(find.text('create organization page'), findsOneWidget);
    });

    testWidgets('shows nothing while there is no organisation and no error', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHeaderUnderTest(
          FakeWorkspaceNotifier(const WorkspaceState(isLoading: true)),
        ),
      );

      expect(find.text('Retry'), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });
}
