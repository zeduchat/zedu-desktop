import 'dart:async';

import '../../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

const _demoNames = [
  'HNG Workspace',
  'TeamFlow Collective',
  'Coffee & Code House',
  'ConnectHub',
];

void main() {
  group('WorkspaceNotifier', () {
    late MockApiBaseService mockApi;
    late MockSecureStorageService mockStorage;

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
      mockStorage = MockSecureStorageService();
      locator.registerSingleton<ApiBaseService>(mockApi);
      locator.registerSingleton<SecureStorageService>(mockStorage);
      when(
        () => mockStorage.replaceAccessToken(any()),
      ).thenAnswer((_) async {});
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
        // The server takes a moment to answer, as the old fixed delay did.
        when(
          () => mockApi.put<Map<String, dynamic>>(
            path: '/users/switch-org',
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return ApiResponseModel(
            data: {
              'data': {'access_token': 'token'},
            },
            statusCode: 200,
          );
        });
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
      when(
        () => mockApi.put<Map<String, dynamic>>(
          path: '/users/switch-org',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => ApiResponseModel(
          data: {
            'data': {'access_token': 'token'},
          },
          statusCode: 200,
        ),
      );
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

    group('after a session reset', () {
      // Each call to /users/organisations gets the next completer, so a test
      // decides when (and how) every request finishes.
      late List<Completer<ApiResponseModel<Map<String, dynamic>>>> requests;

      ApiResponseModel<Map<String, dynamic>> orgs(String id) =>
          ApiResponseModel(
            data: {
              'data': [
                {'id': id, 'name': 'Org $id'},
              ],
            },
            statusCode: 200,
          );

      Future<ProviderContainer> startStaleFetch() async {
        registerConfig(usesMockData: false);
        requests = [];
        when(
          () => mockApi.get<Map<String, dynamic>>(path: '/users/organisations'),
        ).thenAnswer((_) {
          final request = Completer<ApiResponseModel<Map<String, dynamic>>>();
          requests.add(request);
          return request.future;
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(workspaceProvider, (_, _) {});
        await pumpEventQueue();
        expect(requests, hasLength(1));

        // Sign-out and sign-in reset the provider, which fetches again.
        container.invalidate(workspaceProvider);
        container.read(workspaceProvider);
        await pumpEventQueue();
        expect(requests, hasLength(2));

        requests[1].complete(orgs('b'));
        await pumpEventQueue();
        expect(container.read(workspaceProvider).selectedWorkspace?.id, 'b');
        return container;
      }

      test('a late response from the old session is ignored', () async {
        final container = await startStaleFetch();

        requests[0].complete(orgs('a'));
        await pumpEventQueue();

        final state = container.read(workspaceProvider);
        expect(state.workspaces.map((w) => w.id), ['b']);
        expect(state.selectedWorkspace?.id, 'b');
        expect(state.isLoading, isFalse);
        expect(state.errorMessage, isNull);
      });

      test('a late failure from the old session is ignored', () async {
        final container = await startStaleFetch();

        requests[0].completeError(Exception('old session failed'));
        await pumpEventQueue();

        final state = container.read(workspaceProvider);
        expect(state.workspaces.map((w) => w.id), ['b']);
        expect(state.selectedWorkspace?.id, 'b');
        expect(state.errorMessage, isNull);
      });

      test('a refresh in the current session still applies', () async {
        final container = await startStaleFetch();

        final refresh = container
            .read(workspaceProvider.notifier)
            .fetchWorkspaces();
        await pumpEventQueue();
        requests.last.complete(orgs('c'));
        await refresh;

        final state = container.read(workspaceProvider);
        expect(state.workspaces.map((w) => w.id), ['c']);
        expect(state.selectedWorkspace?.id, 'c');
      });
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

    group('switchWorkspace', () {
      const org1 = {'id': 'org-1', 'name': 'Riverside Academy', 'logo_url': ''};
      const org2 = {'id': 'org-2', 'name': 'Cohort 13', 'logo_url': ''};

      void stubSwitchOrg(Future<ApiResponseModel<Map<String, dynamic>>> reply) {
        when(
          () => mockApi.put<Map<String, dynamic>>(
            path: '/users/switch-org',
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) => reply);
      }

      ApiResponseModel<Map<String, dynamic>> tokenReply(Object? token) =>
          ApiResponseModel(
            data: {
              'data': {'access_token': token},
            },
            statusCode: 200,
          );

      Future<ProviderContainer> twoWorkspaces() async {
        registerConfig(usesMockData: false);
        stubOrganisations([org1, org2]);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await loadWorkspaces(container);
        return container;
      }

      test('asks the server to switch and keeps the new token', () async {
        final container = await twoWorkspaces();
        stubSwitchOrg(Future.value(tokenReply('token-2')));
        final target = container.read(workspaceProvider).workspaces.last;

        final error = await container
            .read(workspaceProvider.notifier)
            .switchWorkspace(target);

        expect(error, isNull);
        expect(
          container.read(workspaceProvider).selectedWorkspace?.id,
          'org-2',
        );
        expect(container.read(workspaceProvider).isLoading, isFalse);
        verify(
          () => mockApi.put<Map<String, dynamic>>(
            path: '/users/switch-org',
            data: {'current_org': 'org-2'},
          ),
        ).called(1);
        verify(() => mockStorage.replaceAccessToken('token-2')).called(1);
      });

      test('keeps the current workspace when the server refuses', () async {
        final container = await twoWorkspaces();
        stubSwitchOrg(Future.error(Exception('403')));
        final target = container.read(workspaceProvider).workspaces.last;

        final error = await container
            .read(workspaceProvider.notifier)
            .switchWorkspace(target);

        expect(error, WorkspaceNotifier.switchErrorMessage);
        expect(
          container.read(workspaceProvider).selectedWorkspace?.id,
          'org-1',
        );
        expect(container.read(workspaceProvider).isLoading, isFalse);
        verifyNever(() => mockStorage.replaceAccessToken(any()));
      });

      test('treats a reply without a token as a failed switch', () async {
        final container = await twoWorkspaces();
        stubSwitchOrg(Future.value(tokenReply(null)));
        final target = container.read(workspaceProvider).workspaces.last;

        final error = await container
            .read(workspaceProvider.notifier)
            .switchWorkspace(target);

        expect(error, WorkspaceNotifier.switchErrorMessage);
        expect(
          container.read(workspaceProvider).selectedWorkspace?.id,
          'org-1',
        );
        verifyNever(() => mockStorage.replaceAccessToken(any()));
      });

      test('does nothing for the workspace that is already selected', () async {
        final container = await twoWorkspaces();
        final current = container.read(workspaceProvider).selectedWorkspace!;

        final error = await container
            .read(workspaceProvider.notifier)
            .switchWorkspace(current);

        expect(error, isNull);
        verifyNever(
          () => mockApi.put<Map<String, dynamic>>(
            path: any(named: 'path'),
            data: any(named: 'data'),
          ),
        );
      });

      test('runs switches one after another and the newest one wins', () async {
        final container = await twoWorkspaces();
        final firstReply = Completer<ApiResponseModel<Map<String, dynamic>>>();
        var calls = 0;
        when(
          () => mockApi.put<Map<String, dynamic>>(
            path: '/users/switch-org',
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) =>
              ++calls == 1 ? firstReply.future : Future.value(tokenReply('t3')),
        );
        final notifier = container.read(workspaceProvider.notifier);
        final target = container.read(workspaceProvider).workspaces.last;

        final first = notifier.switchWorkspace(target);
        final second = notifier.switchWorkspace(
          const Workspace(id: 'org-3', name: 'Other', avatar: ''),
        );
        await pumpEventQueue();
        // The first call revoked the token the second one would have sent, so
        // the second waits for it.
        verify(
          () => mockApi.put<Map<String, dynamic>>(
            path: '/users/switch-org',
            data: any(named: 'data'),
          ),
        ).called(1);

        firstReply.complete(tokenReply('token-2'));
        expect(await first, isNull);
        expect(await second, isNull);

        expect(
          container.read(workspaceProvider).selectedWorkspace?.id,
          'org-3',
        );
        expect(container.read(workspaceProvider).isLoading, isFalse);
        verify(
          () => mockApi.put<Map<String, dynamic>>(
            path: '/users/switch-org',
            data: any(named: 'data'),
          ),
        ).called(1);
      });

      test('does not call the server in mock-data mode', () async {
        registerConfig(usesMockData: true);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await loadWorkspaces(container);
        final target = container.read(workspaceProvider).workspaces.last;

        final error = await container
            .read(workspaceProvider.notifier)
            .switchWorkspace(target);

        expect(error, isNull);
        expect(container.read(workspaceProvider).selectedWorkspace, target);
        verifyNever(
          () => mockApi.put<Map<String, dynamic>>(
            path: any(named: 'path'),
            data: any(named: 'data'),
          ),
        );
      });
    });
  });
}
