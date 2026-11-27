import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _LoopbackHttpOverrides extends HttpOverrides {}

class _MemoryStorage extends SecureStorageService {
  String? token;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<void> saveAccessToken(String token, {bool persist = true}) async {
    this.token = token;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _MockAuthRepository repository;
  late _MemoryStorage storage;
  late ProviderContainer container;
  late HttpClient client;

  setUp(() async {
    await locator.reset();
    repository = _MockAuthRepository();
    storage = _MemoryStorage();
    client = HttpOverrides.runWithHttpOverrides(
      HttpClient.new,
      _LoopbackHttpOverrides(),
    );
    client.findProxy = (_) => 'DIRECT';
    locator.registerSingleton<SecureStorageService>(storage);
    locator.registerSingleton<AuthInterceptor>(
      AuthInterceptor(storage: storage),
    );
    locator.registerSingleton<AppConfig>(
      const AppConfig(
        apiBaseUrl: 'https://example.invalid/',
        usesMockData: false,
        googleClientId: 'test-client',
      ),
    );
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    container.read(authNotifierProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    client.close(force: true);
    container.dispose();
    await locator.reset();
  });

  Future<String> callback(Map<String, String> query) async {
    final browserResponse = Completer<String>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'launch') {
        throw StateError('Unexpected URL launcher method: ${call.method}');
      }
      final authUrl = Uri.parse((call.arguments as Map)['url'] as String);
      // application_type is a backend field; Google ignores it on consent.
      expect(authUrl.queryParameters, isNot(contains('application_type')));
      final redirect = Uri.parse(authUrl.queryParameters['redirect_uri']!);
      // Return from launch before waiting for the notifier's HTTP response.
      unawaited(() async {
        try {
          final request = await client.getUrl(
            redirect.replace(queryParameters: query),
          );
          request.persistentConnection = false;
          final response = await request.close();
          expect(response.statusCode, HttpStatus.ok);
          browserResponse.complete(await utf8.decoder.bind(response).join());
        } catch (error, stack) {
          browserResponse.completeError(error, stack);
        }
      }());
      return true;
    });
    final results = await Future.wait<Object?>([
      browserResponse.future.timeout(const Duration(seconds: 5)),
      container.read(authNotifierProvider.notifier).loginWithGoogle(),
    ]);
    return results.first! as String;
  }

  void expectNoExchange() {
    expect(container.read(authNotifierProvider).isLoading, isFalse);
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.unauthenticated,
    );
    expect(storage.token, isNull);
    verifyNever(
      () => repository.signInWithGoogle(
        grantCode: any(named: 'grantCode'),
        redirectUri: any(named: 'redirectUri'),
      ),
    );
  }

  test('denied consent reports cancellation in browser and app', () async {
    final html = await callback({'error': 'access_denied'});

    expect(html, contains('Google sign-in was cancelled.'));
    expect(html, isNot(contains('Sign In Successful!')));
    expect(
      container.read(authNotifierProvider).error,
      'Google sign-in was cancelled.',
    );
    expectNoExchange();
  });

  final invalidCallbacks = <String, Map<String, String>>{
    'provider error': {'error': '<script>untrusted</script>'},
    'missing code': {},
    'empty code': {'code': ''},
    'whitespace code': {'code': '   '},
  };
  for (final entry in invalidCallbacks.entries) {
    test('${entry.key} reports failure without exchanging a code', () async {
      final html = await callback(entry.value);

      expect(html, contains('Google sign-in failed. Please try again.'));
      expect(html, isNot(contains('Sign In Successful!')));
      expect(html, isNot(contains('<script>untrusted</script>')));
      expect(
        container.read(authNotifierProvider).error,
        'Google sign-in failed. Please try again.',
      );
      expectNoExchange();
    });
  }

  test('an error takes precedence over a code in the same callback', () async {
    final html = await callback({'error': 'access_denied', 'code': 'ignored'});

    expect(html, contains('Google sign-in was cancelled.'));
    expectNoExchange();
  });

  test('a valid sign-in can succeed after cancelled consent', () async {
    await callback({'error': 'access_denied'});
    final user = User(
      id: 'google-user',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.invalid',
      phone: '',
      username: 'test-user',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'test-org',
      currentOrganisationSlug: 'test-org',
      avatarUrl: '',
      defaultAvatarUrl: '',
    );
    when(
      () => repository.signInWithGoogle(
        grantCode: 'valid-code',
        redirectUri: 'http://127.0.0.1:8000',
      ),
    ).thenAnswer(
      (_) async => Success(
        AuthSession(
          user: user,
          accessToken: 'test-token',
          accessTokenExpiresIn: DateTime(2027),
        ),
      ),
    );

    final html = await callback({'code': 'valid-code'});

    expect(html, contains('Sign In Successful!'));
    final state = container.read(authNotifierProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.user, same(user));
    expect(state.error, isNull);
    expect(state.isLoading, isFalse);
    expect(storage.token, 'test-token');
    verify(
      () => repository.signInWithGoogle(
        grantCode: 'valid-code',
        redirectUri: 'http://127.0.0.1:8000',
      ),
    ).called(1);
  });
}
