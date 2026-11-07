import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

// One wrong password must never claim the session expired and never repeat
// the backend's per-credential wording: the login screen shows one generic
// message that doesn't reveal, or mislabel, the failing credential.
void main() {
  group('AuthNotifier login failure messages', () {
    late MockAuthRepository repository;
    late MockSecureStorageService storage;
    late ProviderContainer container;

    setUp(() {
      repository = MockAuthRepository();
      storage = MockSecureStorageService();

      when(() => storage.getAccessToken()).thenAnswer((_) async => null);
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

    Future<String> errorOnRejectedLogin(ApiFailure failure) async {
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Failure<AuthSession>(failure));

      await container
          .read(authNotifierProvider.notifier)
          .login(email: 'ada@example.com', password: 'not-the-password');

      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.error, isNotNull);
      return state.error!;
    }

    test('400 with per-credential wording shows the generic message', () async {
      final error = await errorOnRejectedLogin(
        const ApiFailure(
          message: 'Invalid email and password supplied',
          statusCode: 400,
          kind: ApiFailureKind.client,
        ),
      );
      expect(error, AuthNotifier.invalidCredentialsMessage);
      expect(error, isNot(contains('Invalid email and password supplied')));
    });

    test(
      '401 on the login route shows the generic message, not session expiry',
      () async {
        final error = await errorOnRejectedLogin(
          const ApiFailure(
            message: 'Unauthorized',
            statusCode: 401,
            kind: ApiFailureKind.unauthorized,
          ),
        );
        expect(error, AuthNotifier.invalidCredentialsMessage);
        expect(error, isNot(AuthNotifier.sessionExpiredMessage));
      },
    );

    test(
      'an identically-rephrased rejection also shows the generic message',
      () async {
        // The backend may phrase the same rejection differently; the mapping
        // must not depend on one exact sentence.
        final error = await errorOnRejectedLogin(
          const ApiFailure(
            message: 'Incorrect password supplied',
            statusCode: 400,
            kind: ApiFailureKind.client,
          ),
        );
        expect(error, AuthNotifier.invalidCredentialsMessage);
      },
    );

    test('a rate-limited login keeps saying what actually happened', () async {
      const tooMany = 'Too many attempts, try again later';
      final error = await errorOnRejectedLogin(
        const ApiFailure(
          message: tooMany,
          statusCode: 429,
          kind: ApiFailureKind.client,
        ),
      );
      expect(error, tooMany);
      expect(error, isNot(AuthNotifier.invalidCredentialsMessage));
    });

    test('a network failure keeps its offline message', () async {
      final error = await errorOnRejectedLogin(
        const ApiFailure(
          message: 'Failed host lookup',
          kind: ApiFailureKind.network,
        ),
      );
      expect(
        error,
        'No internet connection. Check your network and try again.',
      );
      expect(error, isNot(AuthNotifier.invalidCredentialsMessage));
    });
  });
}
