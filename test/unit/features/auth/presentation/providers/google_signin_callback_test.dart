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

  /// States and redirect URIs of each launched attempt, in order.
  final launchedStates = <String>[];
  late Uri lastRedirect;

  Future<HttpClientResponse> send(String method, Uri uri) async {
    final request = await client.openUrl(method, uri);
    request.persistentConnection = false;
    return request.close();
  }

  /// Runs one sign-in attempt. Each of [ignored] is sent first, as a method
  /// and a URI built from the redirect URI and the attempt's state, and must
  /// get a 404. Then the callback with [query] plus the matching state is
  /// sent and its page is returned.
  Future<String> callback(
    Map<String, String> query, {
    List<(String, Uri Function(Uri redirect, String state))> ignored = const [],
  }) async {
    final browserResponse = Completer<String>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'launch') {
        throw StateError('Unexpected URL launcher method: ${call.method}');
      }
      final authUrl = Uri.parse((call.arguments as Map)['url'] as String);
      final redirect = Uri.parse(authUrl.queryParameters['redirect_uri']!);
      final state = authUrl.queryParameters['state']!;
      launchedStates.add(state);
      lastRedirect = redirect;
      // Return from launch before waiting for the notifier's HTTP response.
      unawaited(() async {
        try {
          for (final (method, build) in ignored) {
            final response = await send(method, build(redirect, state));
            expect(response.statusCode, HttpStatus.notFound);
            await response.drain<void>();
          }
          final response = await send(
            'GET',
            redirect.replace(queryParameters: {...query, 'state': state}),
          );
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

  Future<void> expectListenerClosed() async {
    await expectLater(
      send('GET', lastRedirect),
      throwsA(isA<SocketException>()),
    );
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
    await expectListenerClosed();
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

    expect(html, contains('Return to Zedu'));
    expect(html, isNot(contains('Successful')));
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

  test('each attempt sends a fresh, unguessable state', () async {
    launchedStates.clear();
    await callback({'error': 'access_denied'});
    await callback({'error': 'access_denied'});

    expect(launchedStates, hasLength(2));
    expect(launchedStates.first, isNot(launchedStates.last));
    for (final state in launchedStates) {
      expect(state.length, greaterThanOrEqualTo(43));
    }
  });

  test('unrelated and mismatched requests do not end the attempt', () async {
    when(
      () => repository.signInWithGoogle(
        grantCode: any(named: 'grantCode'),
        redirectUri: any(named: 'redirectUri'),
      ),
    ).thenAnswer((_) async => Failure(ApiFailure.unknown(Exception('x'))));

    final html = await callback(
      {'code': 'valid-code'},
      ignored: [
        (
          'GET',
          (redirect, state) => redirect.replace(
            path: '/unrelated',
            queryParameters: {'code': 'stray', 'state': state},
          ),
        ),
        (
          'GET',
          (redirect, _) => redirect.replace(
            queryParameters: {'code': 'stray', 'state': 'wrong'},
          ),
        ),
        (
          'GET',
          (redirect, _) => redirect.replace(queryParameters: {'code': 'stray'}),
        ),
        (
          'GET',
          (redirect, _) => redirect.replace(
            queryParameters: {'error': 'access_denied', 'state': 'wrong'},
          ),
        ),
        (
          'POST',
          (redirect, state) => redirect.replace(
            queryParameters: {'code': 'stray', 'state': state},
          ),
        ),
      ],
    );

    expect(html, contains('Return to Zedu'));
    verify(
      () => repository.signInWithGoogle(
        grantCode: 'valid-code',
        redirectUri: any(named: 'redirectUri'),
      ),
    ).called(1);
    verifyNever(
      () => repository.signInWithGoogle(
        grantCode: 'stray',
        redirectUri: any(named: 'redirectUri'),
      ),
    );
    await expectListenerClosed();
  });
}
