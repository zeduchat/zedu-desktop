import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockApi extends Mock implements ApiBaseService {}

class _MockRepo extends Mock implements UserProfileRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'me',
      firstName: 'Ada',
      lastName: 'Lovelace',
      email: 'ada@example.com',
      phone: '',
      username: 'ada',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'A',
      currentOrganisationSlug: 'a',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

class _Workspaces extends WorkspaceNotifier {
  @override
  WorkspaceState build() => WorkspaceState(
    selectedWorkspace: Workspace(id: 'A', name: 'WS A', avatar: ''),
  );
}

void main() {
  group('SecuritySessionModel.fromJson (Ziki #587)', () {
    test('maps a session from GET /users/{id}/sessions', () {
      final created = DateTime(2026, 11, 4, 13, 7);
      final updated = DateTime(2026, 11, 4, 15, 30);
      final session = SecuritySessionModel.fromJson({
        'id': 's1',
        'owner_id': 'u1',
        'is_live': true,
        'created_at': created.toUtc().toIso8601String(),
        'updated_at': updated.toUtc().toIso8601String(),
      });

      expect(session.date, 'Nov 4, 2026 1:07 PM');
      expect(session.lastActive, 'Nov 4, 2026 3:30 PM');
      expect(session.status, 'Active');
      // The API sends no device or location; nothing is made up.
      expect(session.device, SecuritySessionModel.unknown);
      expect(session.location, SecuritySessionModel.unknown);
    });

    test('keeps the session id and whether it is live (Ziki #2797)', () {
      final live = SecuritySessionModel.fromJson({'id': 's1', 'is_live': true});
      expect(live.id, 's1');
      expect(live.isLive, isTrue);
      expect(live.canRevoke, isTrue);

      final ended = SecuritySessionModel.fromJson({
        'id': 's2',
        'is_live': false,
      });
      expect(ended.canRevoke, isFalse);

      final noId = SecuritySessionModel.fromJson({'is_live': true});
      expect(noId.id, '');
      expect(noId.canRevoke, isFalse);
    });

    test('a session that is no longer live shows as signed out', () {
      final session = SecuritySessionModel.fromJson({'is_live': false});
      expect(session.status, 'Signed out');
    });

    test('midnight and noon use 12', () {
      expect(
        SecuritySessionModel.fromJson({
          'created_at': DateTime(2026, 1, 2, 0, 5).toUtc().toIso8601String(),
        }).date,
        'Jan 2, 2026 12:05 AM',
      );
      expect(
        SecuritySessionModel.fromJson({
          'created_at': DateTime(2026, 1, 2, 12, 5).toUtc().toIso8601String(),
        }).date,
        'Jan 2, 2026 12:05 PM',
      );
    });

    test('keeps display values from the mock data', () {
      final session = SecuritySessionModel.fromJson({
        'device': 'Chrome',
        'location': 'Lagos',
        'date': 'May 8, 2026 1:07 PM',
        'last_active': 'May 8, 2026 3:07 PM',
        'status': 'Active',
      });
      expect(session.device, 'Chrome');
      expect(session.location, 'Lagos');
      expect(session.date, 'May 8, 2026 1:07 PM');
    });
  });

  group('UserProfileRemoteDataSourceImpl.getSecuritySessions (Ziki #587)', () {
    late _MockApi api;
    late UserProfileRemoteDataSourceImpl datasource;

    setUp(() {
      api = _MockApi();
      datasource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(apiBaseUrl: '', usesMockData: false),
        apiBaseService: api,
      );
    });

    void stub(Map<String, dynamic> body) {
      when(
        () => api.get<Map<String, dynamic>>(path: '/users/u1/sessions'),
      ).thenAnswer(
        (_) async =>
            ApiResponseModel<Map<String, dynamic>>(data: body, statusCode: 200),
      );
    }

    test('asks GET /users/{user_id}/sessions', () async {
      stub({
        'data': [
          {'id': 's1', 'is_live': true, 'created_at': '2026-11-04T12:07:00Z'},
        ],
      });

      final sessions = await datasource.getSecuritySessions(userId: 'u1');

      expect(sessions, hasLength(1));
      expect(sessions.single.status, 'Active');
      verify(
        () => api.get<Map<String, dynamic>>(path: '/users/u1/sessions'),
      ).called(1);
      verifyNever(
        () => api.get<Map<String, dynamic>>(path: '/profile/security/sessions'),
      );
    });

    test('no data means no sessions', () async {
      stub(const {});

      expect(await datasource.getSecuritySessions(userId: 'u1'), isEmpty);
    });
  });

  group('UserProfileRemoteDataSourceImpl.revokeSession (Ziki #2797)', () {
    test('signs the session out with PUT /users/revoke-session', () async {
      final api = _MockApi();
      final datasource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(apiBaseUrl: '', usesMockData: false),
        apiBaseService: api,
      );
      when(
        () => api.put<dynamic>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<dynamic>(
          data: <String, dynamic>{},
          statusCode: 200,
        ),
      );

      await datasource.revokeSession(userId: 'u1', sessionId: 's1');

      verify(
        () => api.put<dynamic>(
          path: '/users/revoke-session',
          data: {'user_id': 'u1', 'access_token_id': 's1'},
        ),
      ).called(1);
    });

    test('does not call the API in mock mode', () async {
      final api = _MockApi();
      final datasource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(apiBaseUrl: '', usesMockData: true),
        apiBaseService: api,
      );

      await datasource.revokeSession(userId: 'u1', sessionId: 's1');

      verifyZeroInteractions(api);
    });
  });

  group('UserProfileNotifier loads the signed-in user\'s sessions', () {
    late _MockRepo repo;

    setUp(() {
      repo = _MockRepo();
      final storage = _MockStorage();
      locator.registerSingleton<SecureStorageService>(storage);
      when(() => storage.readData(any())).thenAnswer((_) async => null);
      Future<Result<T>> failed<T>() async =>
          Failure<T>(const ApiFailure(message: 'unavailable'));
      when(() => repo.getAccount()).thenAnswer((_) => failed());
      when(
        () => repo.getNotificationPreferences(orgId: any(named: 'orgId')),
      ).thenAnswer((_) => failed());
      when(
        () => repo.getSecuritySessions(userId: any(named: 'userId')),
      ).thenAnswer((_) async => const Success([]));
      when(
        () => repo.getOrganization(orgId: any(named: 'orgId')),
      ).thenAnswer((_) => failed());
      when(
        () => repo.getTeamMembers(orgId: any(named: 'orgId')),
      ).thenAnswer((_) => failed());
      when(() => repo.getRolesAndPermissions()).thenAnswer((_) => failed());
      when(() => repo.getBillingInfo()).thenAnswer((_) => failed());
    });

    tearDown(() async => locator.reset());

    ProviderContainer container({required bool signedIn}) {
      final c = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repo),
          workspaceProvider.overrideWith(_Workspaces.new),
          if (signedIn) authNotifierProvider.overrideWith(_SignedIn.new),
        ],
      );
      addTearDown(c.dispose);
      if (signedIn) c.listen(authNotifierProvider, (_, _) {});
      c.listen(userProfileNotifierProvider, (_, _) {});
      return c;
    }

    test('asks for the sessions of the signed-in user', () async {
      container(signedIn: true);
      await pumpEventQueue();

      verify(() => repo.getSecuritySessions(userId: 'me')).called(1);
    });

    test('revoking a session marks it signed out (Ziki #2797)', () async {
      when(
        () => repo.getSecuritySessions(userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => const Success([
          SecuritySession(
            id: 's1',
            device: 'Chrome',
            location: 'Lagos',
            date: 'd',
            lastActive: 'l',
            status: 'Active',
            isLive: true,
          ),
          SecuritySession(
            id: 's2',
            device: 'Chrome',
            location: 'Lagos',
            date: 'd',
            lastActive: 'l',
            status: 'Active',
            isLive: true,
          ),
        ]),
      );
      when(
        () => repo.revokeSession(
          userId: any(named: 'userId'),
          sessionId: any(named: 'sessionId'),
        ),
      ).thenAnswer((_) async => const Success<void>(null));
      when(
        () => repo.getRolesAndPermissions(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => const Success([]));
      locator.registerSingleton<AppConfig>(
        const AppConfig(apiBaseUrl: '', usesMockData: false),
      );
      final c = container(signedIn: true);
      await pumpEventQueue();

      await c.read(userProfileNotifierProvider.notifier).revokeSession('s1');

      verify(() => repo.revokeSession(userId: 'me', sessionId: 's1')).called(1);
      final state = c.read(userProfileNotifierProvider);
      expect(state.securitySessions.first.status, 'Signed out');
      expect(state.securitySessions.first.canRevoke, isFalse);
      expect(state.securitySessions.last.canRevoke, isTrue);
      expect(state.successMessage, 'Session signed out.');
    });

    test('a failed revoke keeps the session and shows the error', () async {
      when(
        () => repo.getSecuritySessions(userId: any(named: 'userId')),
      ).thenAnswer(
        (_) async => const Success([
          SecuritySession(
            id: 's1',
            device: 'Chrome',
            location: 'Lagos',
            date: 'd',
            lastActive: 'l',
            status: 'Active',
            isLive: true,
          ),
        ]),
      );
      when(
        () => repo.revokeSession(
          userId: any(named: 'userId'),
          sessionId: any(named: 'sessionId'),
        ),
      ).thenAnswer(
        (_) async => const Failure<void>(ApiFailure(message: 'Nope')),
      );
      when(
        () => repo.getRolesAndPermissions(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => const Success([]));
      locator.registerSingleton<AppConfig>(
        const AppConfig(apiBaseUrl: '', usesMockData: false),
      );
      final c = container(signedIn: true);
      await pumpEventQueue();

      await c.read(userProfileNotifierProvider.notifier).revokeSession('s1');

      final state = c.read(userProfileNotifierProvider);
      expect(state.securitySessions.single.canRevoke, isTrue);
      expect(state.error, isNotNull);
      expect(state.isSaving, isFalse);
    });

    test('asks for none while nobody is signed in', () async {
      container(signedIn: false);
      await pumpEventQueue();

      verifyNever(() => repo.getSecuritySessions(userId: any(named: 'userId')));
    });
  });
}
