import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockRepo extends Mock implements UserProfileRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

class _MockApi extends Mock implements ApiBaseService {}

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
  late _MockRepo repo;
  late _MockApi api;

  setUp(() {
    repo = _MockRepo();
    api = _MockApi();
    final storage = _MockStorage();
    locator.registerSingleton<SecureStorageService>(storage);
    locator.registerSingleton<ApiBaseService>(api);
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: '', usesMockData: false),
    );
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    Future<Result<T>> failed<T>() async =>
        Failure<T>(const ApiFailure(message: 'unavailable'));
    when(() => repo.getAccount()).thenAnswer((_) => failed());
    when(
      () => repo.getNotificationPreferences(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(
      () => repo.getSecuritySessions(userId: any(named: 'userId')),
    ).thenAnswer((_) => failed());
    when(
      () => repo.getOrganization(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(
      () => repo.getTeamMembers(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(
      () => repo.getRolesAndPermissions(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(() => repo.getBillingInfo()).thenAnswer((_) => failed());
  });

  tearDown(() async => locator.reset());

  test('leaving the workspace says so (Ziki #3049)', () async {
    when(
      () => api.delete<Map<String, dynamic>>(path: any(named: 'path')),
    ).thenAnswer(
      (_) async => const ApiResponseModel<Map<String, dynamic>>(
        data: <String, dynamic>{},
        statusCode: 200,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        userProfileRepositoryProvider.overrideWithValue(repo),
        workspaceProvider.overrideWith(_Workspaces.new),
        authNotifierProvider.overrideWith(_SignedIn.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authNotifierProvider, (_, _) {});
    container.listen(userProfileNotifierProvider, (_, _) {});
    await pumpEventQueue();

    await container
        .read(userProfileNotifierProvider.notifier)
        .leaveOrganization();

    verify(
      () => api.delete<Map<String, dynamic>>(path: '/organisations/A/users/me'),
    ).called(1);
    final message = container.read(userProfileNotifierProvider).successMessage;
    expect(message, 'You left the workspace.');
    expect(message, isNot(contains('signed out')));
  });
}
