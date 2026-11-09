import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeNotificationService implements NotificationService {
  int initCalls = 0;

  @override
  Future<void> init() async => initCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const windowChannel = MethodChannel('window_manager');
  const trayChannel = MethodChannel('tray_manager');
  late List<MethodCall> windowCalls;
  late List<MethodCall> trayCalls;
  late _FakeNotificationService notifications;

  setUp(() {
    windowCalls = [];
    trayCalls = [];
    notifications = _FakeNotificationService();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(windowChannel, (call) async {
      windowCalls.add(call);
      // Answer the state questions show() and focus() ask first.
      return switch (call.method) {
        'isMinimized' || 'isMaximized' || 'isFullScreen' => false,
        'isVisible' || 'isFocused' => true,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(trayChannel, (call) async {
      trayCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(windowChannel, null);
    messenger.setMockMethodCallHandler(trayChannel, null);
  });

  Future<void> pumpManager(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: const MaterialApp(
          home: DesktopManager(child: Text('app content')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  dynamic stateOf(WidgetTester tester) =>
      tester.state(find.byType(DesktopManager));

  group('DesktopManager (Ziki #2437)', () {
    testWidgets(
      'prevents close, sets up the tray and notifications, and shows the app',
      (tester) async {
        await pumpManager(tester);

        expect(find.text('app content'), findsOneWidget);
        final preventClose = windowCalls.firstWhere(
          (c) => c.method == 'setPreventClose',
        );
        expect((preventClose.arguments as Map)['isPreventClose'], isTrue);
        final setIcon = trayCalls.firstWhere((c) => c.method == 'setIcon');
        // The tray plugin resolves the path inside the bundled assets, so it
        // must name a declared asset (staging passed 'app_icon.ico').
        expect(
          ((setIcon.arguments as Map)['iconPath'] as String).replaceAll(
            r'\',
            '/',
          ),
          endsWith('flutter_assets/${trayIconAsset(defaultTargetPlatform)}'),
        );
        expect(trayCalls.map((c) => c.method), contains('setContextMenu'));
        expect(notifications.initCalls, 1);
      },
    );

    testWidgets('closing the window hides it instead of quitting', (
      tester,
    ) async {
      await pumpManager(tester);
      windowCalls.clear();

      stateOf(tester).onWindowClose();
      await tester.pumpAndSettle();

      expect(windowCalls.map((c) => c.method), ['hide']);
    });

    testWidgets('Show Zedu in the tray menu shows and focuses the window', (
      tester,
    ) async {
      await pumpManager(tester);
      windowCalls.clear();

      stateOf(tester).onTrayMenuItemClick(MenuItem(key: 'show_window'));
      await tester.pumpAndSettle();

      final actions = windowCalls
          .map((c) => c.method)
          .where((m) => !m.startsWith('is'));
      expect(actions, ['show', 'focus']);
    });

    testWidgets('Exit in the tray menu turns off close-to-tray, then quits', (
      tester,
    ) async {
      await pumpManager(tester);
      windowCalls.clear();

      stateOf(tester).onTrayMenuItemClick(MenuItem(key: 'exit_app'));
      await tester.pumpAndSettle();

      expect(windowCalls.map((c) => c.method), ['setPreventClose', 'destroy']);
      expect((windowCalls.first.arguments as Map)['isPreventClose'], isFalse);
    });
  });

  group('trayIconAsset', () {
    test('uses a bundled .ico on Windows and the PNG logo elsewhere', () {
      expect(
        trayIconAsset(TargetPlatform.windows),
        'assets/pngs/tray_icon.ico',
      );
      expect(trayIconAsset(TargetPlatform.macOS), 'assets/pngs/zedu_logo.png');
      expect(trayIconAsset(TargetPlatform.linux), 'assets/pngs/zedu_logo.png');
    });

    test('the tray icons are declared assets', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
        final data = await rootBundle.load(trayIconAsset(platform));
        expect(data.lengthInBytes, greaterThan(0));
      }
    });
  });
}
