import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
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
