import 'package:flutter/services.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockAuthInterceptor extends Mock implements AuthInterceptor {}

User _user() => User(
  id: 'user-1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  phone: '',
  username: 'ada',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026, 1, 1),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'org-1',
  avatarUrl: '',
  defaultAvatarUrl: '',
  status: const UserStatus(online: true),
);

AuthSession _session() => AuthSession(
  user: _user(),
  accessToken: 'new-token',
  accessTokenExpiresIn: DateTime.now().add(const Duration(hours: 1)),
);

// The macOS keychain error from the report (missing entitlement).
final _keychainError = PlatformException(
  code: 'Unexpected security result code',
  message: 'Code: -34018, A required entitlement isn\'t present.',
);

// A failed keychain write after a successful sign-in must not leave the
// sign-in spinner running: the session continues in memory (Ziki #3485).
void main() {
  late MockAuthRepository repository;
  late MockSecureStorageService storage;
  late ProviderContainer container;

  setUp(() {
    repository = MockAuthRepository();
    storage = MockSecureStorageService();

    when(() => storage.getAccessToken()).thenAnswer((_) async => null);
    when(() => storage.deleteAccessToken()).thenAnswer((_) async {});
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Success(_session()));
    when(
      () => repository.verifyMagicLink(token: any(named: 'token')),
    ).thenAnswer((_) async => Success(_session()));

    locator.registerSingleton<SecureStorageService>(storage);
    locator.registerSingleton<AuthInterceptor>(MockAuthInterceptor());

    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await locator.reset();
  });

  void keychainWriteFails() {
    when(
      () => storage.saveAccessToken('new-token', persist: true),
    ).thenThrow(_keychainError);
    when(
      () => storage.saveAccessToken('new-token', persist: false),
    ).thenAnswer((_) async {});
  }

  void everyKeychainCallFails() {
    when(
      () => storage.saveAccessToken(any(), persist: any(named: 'persist')),
    ).thenThrow(_keychainError);
  }

  Future<void> signIn(String how) {
    final notifier = container.read(authNotifierProvider.notifier);
    return how == 'login'
        ? notifier.login(email: 'ada@example.com', password: 'secret')
        : notifier.verifyMagicLink(token: 'magic');
  }

  for (final how in ['login', 'magic link']) {
    group('$how when the keychain write fails', () {
      test('finishes signing in and stops loading', () async {
        keychainWriteFails();

        await signIn(how);

        final state = container.read(authNotifierProvider);
        expect(state.status, AuthStatus.authenticated);
        expect(state.user?.id, 'user-1');
        expect(state.isLoading, isFalse);
      });

      test('keeps the token in memory for this run instead', () async {
        keychainWriteFails();

        await signIn(how);

        verify(
          () => storage.saveAccessToken('new-token', persist: false),
        ).called(1);
      });

      test('still signs in when the in-memory fallback also errors', () async {
        everyKeychainCallFails();

        await expectLater(signIn(how), completes);

        final state = container.read(authNotifierProvider);
        expect(state.status, AuthStatus.authenticated);
        expect(state.isLoading, isFalse);
      });
    });
  }

  test('login with Remember me on saves the token once, persisted', () async {
    when(
      () => storage.saveAccessToken(any(), persist: any(named: 'persist')),
    ).thenAnswer((_) async {});

    await container
        .read(authNotifierProvider.notifier)
        .login(email: 'ada@example.com', password: 'secret');

    verify(() => storage.saveAccessToken('new-token', persist: true)).called(1);
    verifyNever(() => storage.saveAccessToken(any(), persist: false));
  });

  test(
    'login with Remember me off never writes the token to the keychain',
    () async {
      when(
        () => storage.saveAccessToken(any(), persist: any(named: 'persist')),
      ).thenAnswer((_) async {});

      await container
          .read(authNotifierProvider.notifier)
          .login(
            email: 'ada@example.com',
            password: 'secret',
            rememberMe: false,
          );

      verify(
        () => storage.saveAccessToken('new-token', persist: false),
      ).called(1);
      verifyNever(() => storage.saveAccessToken(any(), persist: true));
    },
  );
}
