import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

final _user = User(
  id: 'u1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  phone: '',
  username: 'ada',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'org-1',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

void main() {
  group('AuthNotifier on a 401', () {
    late MockAuthRepository repository;
    late MockSecureStorageService storage;
    late AuthInterceptor interceptor;
    late ProviderContainer container;

    setUp(() {
      repository = MockAuthRepository();
      storage = MockSecureStorageService();
      interceptor = AuthInterceptor(storage: storage);

      when(() => storage.deleteAccessToken()).thenAnswer((_) async {});

      locator.registerSingleton<SecureStorageService>(storage);
      locator.registerSingleton<AuthInterceptor>(interceptor);

      container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    tearDown(() async {
      await locator.reset();
    });

    Future<AuthState> settled() {
      final completer = Completer<AuthState>();
      final subscription = container.listen<AuthState>(authNotifierProvider, (
        previous,
        next,
      ) {
        if (next.status != AuthStatus.unknown && !completer.isCompleted) {
          completer.complete(next);
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);
      return completer.future.timeout(const Duration(seconds: 2));
    }

    Future<void> signIn() async {
      when(() => storage.getAccessToken()).thenAnswer((_) async => 'token');
      when(
        () => repository.getCurrentUser(),
      ).thenAnswer((_) async => Success<User>(_user));
      final state = await settled();
      expect(state.status, AuthStatus.authenticated);
    }

    test('ends a signed-in session and flags it as expired', () async {
      await signIn();

      interceptor.onUnauthorized!();
      final state = container.read(authNotifierProvider);

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
      expect(state.sessionExpired, isTrue);
      expect(state.error, isNull);
    });

    test('a second 401 from an in-flight request is not flagged', () async {
      await signIn();

      interceptor.onUnauthorized!();
      interceptor.onUnauthorized!();

      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.sessionExpired, isFalse);
    });

    test('a 401 while signed out (wrong password) is not flagged', () async {
      when(() => storage.getAccessToken()).thenAnswer((_) async => null);
      expect((await settled()).status, AuthStatus.unauthenticated);

      interceptor.onUnauthorized!();

      expect(container.read(authNotifierProvider).sessionExpired, isFalse);
    });

    test('logging out is not flagged as an expired session', () async {
      await signIn();

      await container.read(authNotifierProvider.notifier).logout();

      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.sessionExpired, isFalse);
    });

    test('signing in again clears the flag', () async {
      await signIn();
      interceptor.onUnauthorized!();
      expect(container.read(authNotifierProvider).sessionExpired, isTrue);

      when(
        () => repository.login(email: 'ada@example.com', password: 'pw'),
      ).thenAnswer(
        (_) async => Success<AuthSession>(
          AuthSession(
            accessToken: 'new',
            user: _user,
            accessTokenExpiresIn: DateTime(2027),
          ),
        ),
      );
      when(
        () => storage.saveAccessToken('new', persist: true),
      ).thenAnswer((_) async {});

      await container
          .read(authNotifierProvider.notifier)
          .login(email: 'ada@example.com', password: 'pw');

      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.sessionExpired, isFalse);
    });
  });
}
