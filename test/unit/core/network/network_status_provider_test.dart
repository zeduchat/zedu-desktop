import 'dart:async';

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

    group('out-of-order checks (#2676)', () {
      late List<Completer<bool>> checks;
      late ProviderContainer container;

      setUp(() {
        checks = [];
        container = ProviderContainer(
          overrides: [
            reachabilityCheckerProvider.overrideWithValue(() {
              final check = Completer<bool>();
              checks.add(check);
              return check.future;
            }),
          ],
        );
        addTearDown(container.dispose);
      });

      test(
        'an older offline result does not overwrite a newer online one',
        () async {
          container.read(networkStatusProvider);
          final newer = container
              .read(networkStatusProvider.notifier)
              .checkReachability();
          expect(checks, hasLength(2));

          checks[1].complete(true);
          await newer;
          checks[0].complete(false);
          await pumpEventQueue();

          expect(container.read(networkStatusProvider), NetworkStatus.online);
        },
      );

      test('an older failed check does not overwrite a newer result', () async {
        container.read(networkStatusProvider);
        final newer = container
            .read(networkStatusProvider.notifier)
            .checkReachability();

        checks[1].complete(true);
        await newer;
        checks[0].completeError(Exception('lookup failed'));
        await pumpEventQueue();

        expect(container.read(networkStatusProvider), NetworkStatus.online);
      });

      test(
        'an older online result does not overwrite a newer offline one',
        () async {
          container.read(networkStatusProvider);
          final newer = container
              .read(networkStatusProvider.notifier)
              .checkReachability();

          checks[1].complete(false);
          await newer;
          checks[0].complete(true);
          await pumpEventQueue();

          expect(container.read(networkStatusProvider), NetworkStatus.offline);
        },
      );
    });

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
