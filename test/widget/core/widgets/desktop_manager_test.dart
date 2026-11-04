import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

class _FakeDesktopNotifier implements DesktopNotifier {
  int initCalls = 0;

  @override
  Future<void> init() async => initCalls++;
}

void main() {
  // window_manager and tray_manager talk to the host over method channels that
  // do not exist in a widget test; without these stubs their futures never
  // complete, so the boot sequence never reaches the notifier.
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['window_manager', 'tray_manager']) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => true,
      );
    }
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['window_manager', 'tray_manager']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  test('core defaults to a no-op notifier when no feature registers one', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(desktopNotifierProvider), isA<NoopDesktopNotifier>());
  });

  testWidgets('DesktopManager initialises the registered desktop notifier', (
    tester,
  ) async {
    final notifier = _FakeDesktopNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [desktopNotifierProvider.overrideWithValue(notifier)],
        child: const DesktopManager(child: SizedBox.shrink()),
      ),
    );

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(notifier.initCalls, 1);
  });
}
