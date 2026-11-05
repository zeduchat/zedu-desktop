import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

class _MockAuthInterceptor extends Mock implements AuthInterceptor {}

/// Counts rebuilds without calling the API, as the real notifier would.
class _CountingWorkspaceNotifier extends WorkspaceNotifier {
  static int builds = 0;

  @override
  WorkspaceState build() {
    builds++;
    return const WorkspaceState();
  }
}

User _user() => User(
  id: 'user-1',
  firstName: 'Test',
  lastName: 'User',
  email: 'test@example.com',
  phone: '+1234567890',
  username: 'testuser',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026, 1, 1),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'slug-org-1',
  avatarUrl: '',
  defaultAvatarUrl: '',
  status: const UserStatus(online: true),
);

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _MockAuthRepository repo;
  late _MockStorage storage;
  late ProviderContainer container;
  late AuthNotifier notifier;

  setUp(() async {
    _CountingWorkspaceNotifier.builds = 0;
    repo = _MockAuthRepository();
    storage = _MockStorage();
    locator.registerSingleton<SecureStorageService>(storage);
    locator.registerSingleton<AuthInterceptor>(_MockAuthInterceptor());

    when(() => storage.getAccessToken()).thenAnswer((_) async => 'token');
    when(() => storage.deleteAccessToken()).thenAnswer((_) async {});
    when(() => storage.saveAccessToken(any())).thenAnswer((_) async {});
    when(() => repo.getCurrentUser()).thenAnswer((_) async => Success(_user()));
    when(
      () => repo.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => Success(
        AuthSession(
          user: _user(),
          accessToken: 'token-2',
          accessTokenExpiresIn: DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
    );

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        workspaceProvider.overrideWith(_CountingWorkspaceNotifier.new),
      ],
    );
    notifier = container.read(authNotifierProvider.notifier);
    await _flush();
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.authenticated,
    );
  });

  tearDown(() async {
    container.dispose();
    await locator.reset();
  });

  test('signing out clears what the session left behind', () async {
    container.read(homeSidebarProvider.notifier).setType(HomeSidebarType.dms);

    await notifier.logout();
    await _flush();

    expect(container.read(homeSidebarProvider), HomeSidebarType.home);
  });

  test('signing out rebuilds a provider that is still being watched', () async {
    final sub = container.listen(workspaceProvider, (_, _) {});
    addTearDown(sub.close);
    expect(_CountingWorkspaceNotifier.builds, 1);

    await notifier.logout();
    container.read(workspaceProvider);

    expect(_CountingWorkspaceNotifier.builds, 2);
  });

  test('signing in again rebuilds it once more, now with the token', () async {
    final sub = container.listen(workspaceProvider, (_, _) {});
    addTearDown(sub.close);

    await notifier.logout();
    container.read(workspaceProvider);
    await notifier.login(email: 'b@example.com', password: 'Password123');
    container.read(workspaceProvider);

    expect(_CountingWorkspaceNotifier.builds, 3);
  });

  test('a second sign-out in a row does not rebuild again', () async {
    final sub = container.listen(workspaceProvider, (_, _) {});
    addTearDown(sub.close);

    await notifier.logout();
    container.read(workspaceProvider);
    await notifier.logout();
    container.read(workspaceProvider);

    expect(_CountingWorkspaceNotifier.builds, 2);
  });

  test('changes that keep the session do not rebuild it', () async {
    final sub = container.listen(workspaceProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(homeSidebarProvider.notifier).setType(HomeSidebarType.dms);
    await _flush();
    container.read(workspaceProvider);

    expect(_CountingWorkspaceNotifier.builds, 1);
    expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
  });
}
