import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

const _demoNames = [
  'HNG Workspace',
  'TeamFlow Collective',
  'Coffee & Code House',
  'ConnectHub',
];

void main() {
  group('WorkspaceNotifier', () {
    late MockApiBaseService mockApi;

    void registerConfig({required bool usesMockData}) {
      locator.registerSingleton<AppConfig>(
        AppConfig(
          apiBaseUrl: 'https://api.example.com',
          usesMockData: usesMockData,
        ),
      );
    }

    void stubOrganisations(List<Map<String, dynamic>> orgs) {
      when(
        () => mockApi.get<Map<String, dynamic>>(path: '/users/organisations'),
      ).thenAnswer(
        (_) async => ApiResponseModel(data: {'data': orgs}, statusCode: 200),
      );
    }

    Future<WorkspaceState> loadWorkspaces(ProviderContainer container) async {
      container.read(workspaceProvider);
      await container.read(workspaceProvider.notifier).fetchWorkspaces();
      return container.read(workspaceProvider);
    }

    setUp(() {
      mockApi = MockApiBaseService();
      locator.registerSingleton<ApiBaseService>(mockApi);
    });

    tearDown(() async {
      await locator.reset();
    });

    test('starts with no organisations instead of demo data', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(workspaceProvider);

      expect(state.workspaces, isEmpty);
      expect(state.selectedWorkspace, isNull);
      // Let the background fetch started by build() finish before teardown.
      await pumpEventQueue();
    });

    group('switchWorkspace', () {
      const x = Workspace(id: 'x', name: 'X', avatar: '');
      const y = Workspace(id: 'y', name: 'Y', avatar: '');
      const z = Workspace(id: 'z', name: 'Z', avatar: '');

      Future<ProviderContainer> loadedOnX() async {
        registerConfig(usesMockData: false);
        stubOrganisations([
          for (final workspace in [x, y, z])
            {'id': workspace.id, 'name': workspace.name},
        ]);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final state = await loadWorkspaces(container);
        expect(state.selectedWorkspace?.id, 'x');
        // Let the background fetch started by build() finish as well.
        await pumpEventQueue();
        return container;
      }

      test('stays on the selected workspace when reselected during the '
          'delay', () async {
        final container = await loadedOnX();
        final notifier = container.read(workspaceProvider.notifier);

        final toY = notifier.switchWorkspace(y);
        final backToX = notifier.switchWorkspace(x);
        await Future.wait([toY, backToX]);

        final state = container.read(workspaceProvider);
        expect(state.selectedWorkspace?.id, 'x');
        expect(state.isLoading, isFalse);
      });

      test('never selects a workspace that a newer switch replaced', () async {
        final container = await loadedOnX();
        final notifier = container.read(workspaceProvider.notifier);
        final selected = <String?>[];
        container.listen(
          workspaceProvider.select((s) => s.selectedWorkspace?.id),
          (_, next) => selected.add(next),
        );

        final toY = notifier.switchWorkspace(y);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final toZ = notifier.switchWorkspace(z);
        await Future.wait([toY, toZ]);

        expect(selected, ['z']);
        expect(container.read(workspaceProvider).isLoading, isFalse);
      });

      test('reselecting with no switch pending keeps a workspace load '
          'running', () async {
        final container = await loadedOnX();
        final notifier = container.read(workspaceProvider.notifier);
        notifier.state = notifier.state.copyWith(isLoading: true);

        await notifier.switchWorkspace(x);

        expect(container.read(workspaceProvider).isLoading, isTrue);
      });

      test('switches once the delay has passed', () async {
        final container = await loadedOnX();

        await container.read(workspaceProvider.notifier).switchWorkspace(y);

        final state = container.read(workspaceProvider);
        expect(state.selectedWorkspace?.id, 'y');
        expect(state.isLoading, isFalse);
      });
    });

    test('shows no organisations when the user belongs to none', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await loadWorkspaces(container);

      expect(state.workspaces, isEmpty);
      expect(state.selectedWorkspace, isNull);
      expect(state.errorMessage, isNull);
    });

    test('shows exactly the organisations returned by the server', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([
        {'id': 'org-1', 'name': 'Riverside Academy', 'logo_url': ''},
        {'id': 'org-2', 'name': 'Cohort 13', 'logo_url': ''},
      ]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await loadWorkspaces(container);

      expect(state.workspaces.map((w) => w.name), [
        'Riverside Academy',
        'Cohort 13',
      ]);
      expect(state.selectedWorkspace?.id, 'org-1');
      expect(state.workspaces.every((w) => w.unreadCount == 0), isTrue);
    });

    test('leaving the only organisation clears the selection', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([
        {'id': 'org-1', 'name': 'Acme'},
      ]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await loadWorkspaces(container);
      expect(container.read(workspaceProvider).selectedWorkspace?.id, 'org-1');

      container.read(workspaceProvider.notifier).removeWorkspace('org-1');

      final state = container.read(workspaceProvider);
      expect(state.workspaces, isEmpty);
      expect(state.selectedWorkspace, isNull);
    });

    test('leaving one of several selects another organisation', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([
        {'id': 'org-1', 'name': 'Acme'},
        {'id': 'org-2', 'name': 'Globex'},
      ]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await loadWorkspaces(container);

      container.read(workspaceProvider.notifier).removeWorkspace('org-1');

      expect(container.read(workspaceProvider).selectedWorkspace?.id, 'org-2');
    });

    test('a newly created organisation is the only one listed', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await loadWorkspaces(container);

      container
          .read(workspaceProvider.notifier)
          .addWorkspace(
            const Workspace(
              id: 'org-new',
              name: 'Riverside Academy',
              avatar: '',
            ),
          );

      final state = container.read(workspaceProvider);
      expect(state.workspaces.map((w) => w.name), ['Riverside Academy']);
      expect(state.selectedWorkspace?.id, 'org-new');
    });

    test('skips organisations without an id', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([
        {'name': 'Organisation without id', 'logo_url': ''},
        {'id': 'org-2', 'name': 'Cohort 13', 'logo_url': ''},
        {'id': '   ', 'name': 'Organisation with blank id', 'logo_url': ''},
      ]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await loadWorkspaces(container);

      expect(state.workspaces.map((w) => w.name), ['Cohort 13']);
      expect(state.workspaces.single.id, 'org-2');
      expect(state.selectedWorkspace?.id, 'org-2');
    });

    test('sets an error and no demo data when loading fails', () async {
      registerConfig(usesMockData: false);
      when(
        () => mockApi.get<Map<String, dynamic>>(path: '/users/organisations'),
      ).thenThrow(Exception('network down'));
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await loadWorkspaces(container);

      expect(state.workspaces, isEmpty);
      expect(state.selectedWorkspace, isNull);
      expect(state.errorMessage, WorkspaceNotifier.loadErrorMessage);
    });

    test('a failed refresh keeps the list and the selection', () async {
      registerConfig(usesMockData: false);
      stubOrganisations([
        {'id': 'org-1', 'name': 'Riverside Academy', 'logo_url': ''},
        {'id': 'org-2', 'name': 'Hillside School', 'logo_url': ''},
      ]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await loadWorkspaces(container);
      final notifier = container.read(workspaceProvider.notifier);
      await notifier.switchWorkspace(
        container.read(workspaceProvider).workspaces.last,
      );

      when(
        () => mockApi.get<Map<String, dynamic>>(path: '/users/organisations'),
      ).thenThrow(Exception('network down'));
      await notifier.fetchWorkspaces();

      final state = container.read(workspaceProvider);
      expect(state.workspaces.map((w) => w.id), ['org-1', 'org-2']);
      expect(state.selectedWorkspace?.id, 'org-2');
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, WorkspaceNotifier.loadErrorMessage);
    });

    test('a successful retry clears the error', () async {
      registerConfig(usesMockData: false);
      when(
        () => mockApi.get<Map<String, dynamic>>(path: '/users/organisations'),
      ).thenThrow(Exception('network down'));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await loadWorkspaces(container);

      stubOrganisations([
        {'id': 'org-1', 'name': 'Riverside Academy', 'logo_url': ''},
      ]);
      await container.read(workspaceProvider.notifier).fetchWorkspaces();

      final state = container.read(workspaceProvider);
      expect(state.errorMessage, isNull);
      expect(state.workspaces.map((w) => w.name), ['Riverside Academy']);
    });

    test('keeps the demo organisations in mock-data mode', () async {
      registerConfig(usesMockData: true);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await loadWorkspaces(container);

      expect(state.workspaces.map((w) => w.name), _demoNames);
      verifyNever(
        () => mockApi.get<Map<String, dynamic>>(path: any(named: 'path')),
      );
    });
  });
}
