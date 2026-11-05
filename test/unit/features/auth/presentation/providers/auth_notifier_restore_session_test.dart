import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  group('AuthNotifier session restore', () {
    late MockAuthRepository repository;
    late MockSecureStorageService storage;
    late ProviderContainer container;

    setUp(() {
      repository = MockAuthRepository();
      storage = MockSecureStorageService();

      when(() => storage.deleteAccessToken()).thenAnswer((_) async {});

      locator.registerSingleton<SecureStorageService>(storage);
      locator.registerSingleton<AuthInterceptor>(
        AuthInterceptor(storage: storage),
      );

      container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    tearDown(() async {
      await locator.reset();
    });

    // Starts the notifier and waits until it has finished restoring.
    Future<AuthState> restoreSession() {
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

    void givenSavedTokenAndFailure(ApiFailure failure) {
      when(
        () => storage.getAccessToken(),
      ).thenAnswer((_) async => 'saved-token');
      when(
        () => repository.getCurrentUser(),
      ).thenAnswer((_) async => Failure<User>(failure));
    }

    for (final kind in [
      ApiFailureKind.network,
      ApiFailureKind.timeout,
      ApiFailureKind.server,
    ]) {
      test('keeps the saved token when /auth/me fails with $kind', () async {
        final failure = ApiFailure(message: 'boom', kind: kind);
        givenSavedTokenAndFailure(failure);

        final state = await restoreSession();

        verifyNever(() => storage.deleteAccessToken());
        expect(state.status, AuthStatus.unauthenticated);
        expect(state.error, failure.friendlyMessage);
        expect(state.sessionRestoreFailed, isTrue);
      });
    }

    group('retrySessionRestore', () {
      const networkFailure = ApiFailure(
        message: 'boom',
        kind: ApiFailureKind.network,
      );

      User user() => User(
        id: 'user-1',
        firstName: 'Ada',
        lastName: 'Okafor',
        email: 'ada@example.com',
        phone: '',
        username: 'ada',
        isVerified: true,
        isOnboarded: true,
        createdAt: DateTime(2026),
        currentOrg: 'org-1',
        currentOrganisationSlug: 'org',
        avatarUrl: '',
        defaultAvatarUrl: '',
      );

      test('signs in once the server answers, without a password', () async {
        givenSavedTokenAndFailure(networkFailure);
        await restoreSession();
        when(
          () => repository.getCurrentUser(),
        ).thenAnswer((_) async => Success<User>(user()));

        final retry = container
            .read(authNotifierProvider.notifier)
            .retrySessionRestore();
        expect(container.read(authNotifierProvider).status, AuthStatus.unknown);
        await retry;

        final state = container.read(authNotifierProvider);
        expect(state.status, AuthStatus.authenticated);
        expect(state.user?.id, 'user-1');
        expect(state.sessionRestoreFailed, isFalse);
        verifyNever(() => storage.deleteAccessToken());
      });

      test('offers retry again when the server is still unreachable', () async {
        givenSavedTokenAndFailure(networkFailure);
        await restoreSession();

        await container
            .read(authNotifierProvider.notifier)
            .retrySessionRestore();

        expect(
          container.read(authNotifierProvider).sessionRestoreFailed,
          isTrue,
        );
        verifyNever(() => storage.deleteAccessToken());
      });

      test('clears the token and shows login when retry gets a 401', () async {
        givenSavedTokenAndFailure(networkFailure);
        await restoreSession();
        when(() => repository.getCurrentUser()).thenAnswer(
          (_) async => const Failure<User>(
            ApiFailure(
              message: 'Unauthorized',
              statusCode: 401,
              kind: ApiFailureKind.unauthorized,
            ),
          ),
        );

        await container
            .read(authNotifierProvider.notifier)
            .retrySessionRestore();

        final state = container.read(authNotifierProvider);
        verify(() => storage.deleteAccessToken()).called(1);
        expect(state.status, AuthStatus.unauthenticated);
        expect(state.sessionRestoreFailed, isFalse);
      });

      test('showLoginForm leaves retry and keeps the token', () async {
        givenSavedTokenAndFailure(networkFailure);
        await restoreSession();

        container.read(authNotifierProvider.notifier).showLoginForm();

        final state = container.read(authNotifierProvider);
        expect(state.status, AuthStatus.unauthenticated);
        expect(state.sessionRestoreFailed, isFalse);
        expect(state.error, isNull);
        verifyNever(() => storage.deleteAccessToken());
      });
    });

    test('deletes the saved token when /auth/me returns 401', () async {
      givenSavedTokenAndFailure(
        const ApiFailure(
          message: 'Unauthorized',
          statusCode: 401,
          kind: ApiFailureKind.unauthorized,
        ),
      );

      final state = await restoreSession();

      verify(() => storage.deleteAccessToken()).called(1);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.error, isNull);
    });
  });
}
