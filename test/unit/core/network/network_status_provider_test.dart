import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  group('apiReachabilityChecker (#12382)', () {
    const baseUrl = 'https://api.example.test/api/v1/';
    late _MockDio client;

    setUpAll(() => registerFallbackValue(Options()));

    setUp(() => client = _MockDio());

    void answer(int statusCode) {
      when(
        () => client.head<void>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: baseUrl),
          statusCode: statusCode,
        ),
      );
    }

    void fail(DioExceptionType type, {int? statusCode}) {
      final request = RequestOptions(path: baseUrl);
      when(
        () => client.head<void>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: request,
          type: type,
          response: statusCode == null
              ? null
              : Response<void>(requestOptions: request, statusCode: statusCode),
        ),
      );
    }

    Future<bool> check() =>
        NetworkStatusNotifier.apiReachabilityChecker(baseUrl, client: client);

    test('asks the API host', () async {
      answer(200);

      expect(await check(), isTrue);
      verify(
        () => client.head<void>(baseUrl, options: any(named: 'options')),
      ).called(1);
    });

    test('any HTTP response is online, even an error status', () async {
      for (final status in [404, 500]) {
        answer(status);
        expect(await check(), isTrue, reason: '$status');
      }
      fail(DioExceptionType.badResponse, statusCode: 503);
      expect(await check(), isTrue);
    });

    test('a connection error or a timeout is offline', () async {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.unknown,
      ]) {
        fail(type);
        expect(await check(), isFalse, reason: '$type');
      }
    });
  });

  group('NetworkStatusNotifier', () {
    test(
      'initializes as online and updates to offline when reachability fails',
      () async {
        final container = ProviderContainer(
          overrides: [
            reachabilityCheckerProvider.overrideWithValue(() async => false),
          ],
        );
        addTearDown(container.dispose);

        // Trigger build
        expect(container.read(networkStatusProvider), NetworkStatus.online);

        // Allow async reachability check to complete
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(container.read(networkStatusProvider), NetworkStatus.offline);
      },
    );

    test('updates to online when reachability succeeds', () async {
      final container = ProviderContainer(
        overrides: [
          reachabilityCheckerProvider.overrideWithValue(() async => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(networkStatusProvider), NetworkStatus.online);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(container.read(networkStatusProvider), NetworkStatus.online);
    });

    test('manual controls override network state correctly', () async {
      final container = ProviderContainer(
        overrides: [
          reachabilityCheckerProvider.overrideWithValue(() async => true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(networkStatusProvider.notifier);

      notifier.setOffline();
      expect(container.read(networkStatusProvider), NetworkStatus.offline);

      notifier.setOnline();
      expect(container.read(networkStatusProvider), NetworkStatus.online);

      notifier.toggle();
      expect(container.read(networkStatusProvider), NetworkStatus.offline);

      notifier.toggle();
      expect(container.read(networkStatusProvider), NetworkStatus.online);
    });

    test(
      'checkReachability transitions state dynamically on network recovery',
      () async {
        bool isConnected = false;
        final container = ProviderContainer(
          overrides: [
            reachabilityCheckerProvider.overrideWithValue(
              () async => isConnected,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Initialize provider
        container.read(networkStatusProvider);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(container.read(networkStatusProvider), NetworkStatus.offline);

        // Simulate connection restored
        isConnected = true;
        await container
            .read(networkStatusProvider.notifier)
            .checkReachability();
        expect(container.read(networkStatusProvider), NetworkStatus.online);
      },
    );

    test('disposing container cleanly cancels monitoring timer', () async {
      final container = ProviderContainer(
        overrides: [
          reachabilityCheckerProvider.overrideWithValue(() async => true),
        ],
      );

      container.read(networkStatusProvider);
      expect(() => container.dispose(), returnsNormally);
    });
  });
}
