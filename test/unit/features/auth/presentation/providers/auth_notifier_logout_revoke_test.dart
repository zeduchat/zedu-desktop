import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

User _user(String id) => User(
  id: id,
  firstName: 'Test',
  lastName: 'User',
  email: '$id@example.com',
  phone: '',
  username: id,
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'org',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

void main() {
  late MockAuthRepository repo;
  late MockSecureStorageService storage;
  late AuthInterceptor interceptor;
  late String? token;

  setUp(() {
    token = 'token-1';
    repo = MockAuthRepository();
    storage = MockSecureStorageService();
    interceptor = AuthInterceptor(storage: storage);
    when(() => storage.getAccessToken()).thenAnswer((_) async => token);
    when(() => storage.deleteAccessToken()).thenAnswer((_) async {
      token = null;
    });
    when(() => storage.readAll()).thenAnswer((_) async => {});
    when(
      () => repo.getCurrentUser(),
    ).thenAnswer((_) async => Success(_user('u1')));
    locator.registerSingleton<SecureStorageService>(storage);
    locator.registerSingleton<AuthInterceptor>(interceptor);
  });

  tearDown(() => locator.reset());

  Future<(ProviderContainer, AuthNotifier)> signedIn() async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);
    await pumpEventQueue();
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.authenticated,
    );
    return (container, notifier);
  }

  group('AuthNotifier.logout revokes the backend session', () {
    test('calls the backend logout before deleting the local token', () async {
      String? tokenDuringRequest;
      when(() => repo.logout()).thenAnswer((_) async {
        tokenDuringRequest = token;
        return const Success(null);
      });
      final (container, notifier) = await signedIn();

      await notifier.logout();

      expect(tokenDuringRequest, 'token-1');
      verifyInOrder([() => repo.logout(), () => storage.deleteAccessToken()]);
      expect(token, isNull);
      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('still signs out locally when the backend call fails', () async {
      when(() => repo.logout()).thenAnswer(
        (_) async => const Failure(
          ApiFailure(
            message: 'No internet connection',
            kind: ApiFailureKind.network,
          ),
        ),
      );
      final (container, notifier) = await signedIn();

      await notifier.logout();

      verify(() => storage.deleteAccessToken()).called(1);
      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('still signs out locally when the backend call throws', () async {
      when(() => repo.logout()).thenThrow(StateError('unexpected'));
      final (container, notifier) = await signedIn();

      await notifier.logout();

      verify(() => storage.deleteAccessToken()).called(1);
      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('still signs out locally when the backend never answers', () async {
      final never = Completer<Result<void>>();
      when(() => repo.logout()).thenAnswer((_) => never.future);
      final (container, notifier) = await signedIn();
      notifier.logoutRequestTimeout = const Duration(milliseconds: 20);

      await notifier.logout().timeout(const Duration(seconds: 2));

      verify(() => storage.deleteAccessToken()).called(1);
      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('does not call the backend when there is no token', () async {
      token = null;
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(authNotifierProvider.notifier);
      await pumpEventQueue();

      await notifier.logout();

      verifyNever(() => repo.logout());
      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('a 401 from the logout request is not reported as expired', () async {
      when(() => repo.logout()).thenAnswer((_) async {
        // What the interceptor does when the backend rejects the token.
        interceptor.onUnauthorized?.call();
        return const Failure(
          ApiFailure(message: 'expired', kind: ApiFailureKind.unauthorized),
        );
      });
      final (container, notifier) = await signedIn();
      final states = <AuthState>[];
      container.listen(authNotifierProvider, (_, next) => states.add(next));

      await notifier.logout();

      expect(states.where((s) => s.sessionExpired), isEmpty);
      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.sessionExpired, isFalse);
    });

    test('an expired session does not call the backend logout', () async {
      final (container, _) = await signedIn();

      interceptor.onUnauthorized?.call();
      await pumpEventQueue();

      verifyNever(() => repo.logout());
      expect(container.read(authNotifierProvider).sessionExpired, isTrue);
    });
  });
}
