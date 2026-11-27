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
  accessToken: 'magic-token',
  accessTokenExpiresIn: DateTime.now().add(const Duration(hours: 1)),
);

// A magic-link sign-in must honour the Remember-me choice the user made when
// requesting the link, including after an app restart (Ziki #2865).
void main() {
  const key = AuthNotifier.magicLinkRememberMeKey;

  late MockAuthRepository repository;
  late MockSecureStorageService storage;
  late Map<String, String> stored;
  late ProviderContainer container;

  ProviderContainer newContainer() {
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repository = MockAuthRepository();
    storage = MockSecureStorageService();
    stored = {};

    when(() => storage.getAccessToken()).thenAnswer((_) async => null);
    when(() => storage.deleteAccessToken()).thenAnswer((_) async {});
    when(
      () => storage.saveAccessToken(any(), persist: any(named: 'persist')),
    ).thenAnswer((_) async {});
    when(() => storage.writeData(any(), any())).thenAnswer((invocation) async {
      stored[invocation.positionalArguments[0] as String] =
          invocation.positionalArguments[1] as String;
    });
    when(() => storage.readData(any())).thenAnswer(
      (invocation) async => stored[invocation.positionalArguments[0]],
    );
    when(() => storage.deleteValue(any())).thenAnswer((invocation) async {
      stored.remove(invocation.positionalArguments[0]);
    });
    when(
      () => repository.verifyMagicLink(token: any(named: 'token')),
    ).thenAnswer((_) async => Success(_session()));
    when(
      () => repository.sendMagicLink(email: any(named: 'email')),
    ).thenAnswer((_) async => const Success<void>(null));

    locator.registerSingleton<SecureStorageService>(storage);
    locator.registerSingleton<AuthInterceptor>(MockAuthInterceptor());

    container = newContainer();
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> verifyLink(ProviderContainer c) =>
      c.read(authNotifierProvider.notifier).verifyMagicLink(token: 'magic');

  test('requesting with Remember me off keeps the token in memory', () async {
    await container
        .read(magicLinkNotifierProvider.notifier)
        .send('ada@example.com', rememberMe: false);

    await verifyLink(container);

    verify(
      () => storage.saveAccessToken('magic-token', persist: false),
    ).called(1);
    verifyNever(() => storage.saveAccessToken(any(), persist: true));
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.authenticated,
    );
  });

  test('requesting with Remember me on persists the token', () async {
    await container
        .read(magicLinkNotifierProvider.notifier)
        .send('ada@example.com', rememberMe: true);

    await verifyLink(container);

    verify(
      () => storage.saveAccessToken('magic-token', persist: true),
    ).called(1);
  });

  test('without a recorded choice the token is persisted', () async {
    await verifyLink(container);

    verify(
      () => storage.saveAccessToken('magic-token', persist: true),
    ).called(1);
    verifyNever(() => storage.saveAccessToken(any(), persist: false));
  });

  test('the choice survives an app restart', () async {
    await container
        .read(magicLinkNotifierProvider.notifier)
        .send('ada@example.com', rememberMe: false);
    expect(stored[key], 'false');

    // A fresh notifier has no in-memory choice, as after a restart.
    final restarted = newContainer();
    await verifyLink(restarted);

    verify(
      () => storage.saveAccessToken('magic-token', persist: false),
    ).called(1);
  });

  test('the stored choice is cleared after it is used', () async {
    await container
        .read(authNotifierProvider.notifier)
        .rememberMagicLinkChoice(false);

    await verifyLink(container);

    expect(stored.containsKey(key), isFalse);
    verify(() => storage.deleteValue(key)).called(1);

    await verifyLink(container);

    verify(
      () => storage.saveAccessToken('magic-token', persist: true),
    ).called(1);
  });

  test('a failed request does not record a choice', () async {
    when(
      () => repository.sendMagicLink(email: any(named: 'email')),
    ).thenAnswer((_) async => Failure<void>(ApiFailure.unknown('down')));

    await container
        .read(magicLinkNotifierProvider.notifier)
        .send('ada@example.com', rememberMe: false);

    expect(stored.containsKey(key), isFalse);
  });

  test('a storage error still signs in, persisting as before', () async {
    when(() => storage.readData(key)).thenThrow(Exception('keyring broken'));

    await verifyLink(container);

    verify(
      () => storage.saveAccessToken('magic-token', persist: true),
    ).called(1);
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.authenticated,
    );
  });
}
