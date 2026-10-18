import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSecureStorage extends Mock implements SecureStorageService {}

// Records the pages it would open instead of launching a browser.
class _TestAuthNotifier extends AuthNotifier {
  final opened = <Uri>[];

  @override
  Future<void> openInBrowser(Uri url) async => opened.add(url);
}

final _session = AuthSession(
  user: User(
    id: 'u1',
    firstName: 'Ada',
    lastName: 'Obi',
    email: 'ada@example.com',
    phone: '',
    username: 'ada',
    isVerified: true,
    isOnboarded: true,
    createdAt: DateTime(2026),
    currentOrg: '',
    currentOrganisationSlug: '',
    avatarUrl: '',
    defaultAvatarUrl: '',
  ),
  accessToken: 'token',
  accessTokenExpiresIn: DateTime(2027),
);

/// Plays the browser coming back to the loopback server after Google.
Future<HttpClientResponse> _redirect(String query) async {
  final client = HttpClient();
  addTearDown(() => client.close(force: true));
  final request = await client.get('127.0.0.1', 8000, '/?$query');
  return request.close();
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 500 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: 'timed out waiting');
}

void main() {
  late _MockAuthRepository repository;
  late ProviderContainer container;
  late _TestAuthNotifier notifier;

  setUp(() async {
    repository = _MockAuthRepository();
    final storage = _MockSecureStorage();
    when(storage.getAccessToken).thenAnswer((_) async => null);
    when(() => storage.saveAccessToken(any())).thenAnswer((_) async {});
    when(
      () => repository.signInWithGoogle(
        grantCode: any(named: 'grantCode'),
        redirectUri: any(named: 'redirectUri'),
      ),
    ).thenAnswer((_) async => Success(_session));

    await locator.reset();
    locator
      ..registerSingleton<AppConfig>(
        const AppConfig(apiBaseUrl: 'http://localhost/', usesMockData: false),
      )
      ..registerSingleton<SecureStorageService>(storage)
      ..registerSingleton<AuthInterceptor>(AuthInterceptor(storage: storage));

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        authNotifierProvider.overrideWith(_TestAuthNotifier.new),
      ],
    );
    notifier =
        container.read(authNotifierProvider.notifier) as _TestAuthNotifier;
    // Let the stored-session check finish before signing in.
    await _until(
      () => container.read(authNotifierProvider).status != AuthStatus.unknown,
    );
  });

  tearDown(() async {
    container.dispose();
    await locator.reset();
  });

  group('AuthNotifier.loginWithGoogle', () {
    test('a quick double-click still signs in once', () async {
      final first = notifier.loginWithGoogle();
      final second = notifier.loginWithGoogle();
      await _until(() => notifier.opened.isNotEmpty);

      final response = await _redirect('code=abc');
      await Future.wait([first, second]);

      expect(response.statusCode, HttpStatus.ok);
      expect(notifier.opened, hasLength(1));
      verify(
        () => repository.signInWithGoogle(
          grantCode: 'abc',
          redirectUri: 'http://127.0.0.1:8000',
        ),
      ).called(1);
      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.error, isNull);
    });

    test('cancelling on Google ends with a message, not a hang', () async {
      final signIn = notifier.loginWithGoogle();
      await _until(() => notifier.opened.isNotEmpty);

      final response = await _redirect('error=access_denied');
      await signIn;

      expect(response.statusCode, HttpStatus.ok);
      verifyNever(
        () => repository.signInWithGoogle(
          grantCode: any(named: 'grantCode'),
          redirectUri: any(named: 'redirectUri'),
        ),
      );
      final state = container.read(authNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, 'Google sign-in was cancelled.');
    });
  });
}
