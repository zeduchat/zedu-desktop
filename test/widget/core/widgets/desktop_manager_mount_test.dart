import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/domain/notification_service.dart';
import '../../../helpers/helpers.dart';

class _FakeNotificationService extends Mock implements NotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const windowChannel = MethodChannel('window_manager');
  const trayChannel = MethodChannel('tray_manager');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> windowCalls;
  late List<MethodCall> trayCalls;

  setUp(() {
    windowCalls = <MethodCall>[];
    trayCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(windowChannel, (call) async {
      windowCalls.add(call);
      // show() and focus() ask whether the window is already visible or
      // focused first; those answers are bools, so a null would throw.
      if (call.method.startsWith('is')) return false;
      return null;
    });
    messenger.setMockMethodCallHandler(trayChannel, (call) async {
      trayCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(windowChannel, null);
    messenger.setMockMethodCallHandler(trayChannel, null);
  });

  group('isDesktopApp', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is true on Windows, macOS and Linux', () {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(isDesktopApp, isTrue, reason: '$platform is a desktop');
      }
    });

    test('is false on a phone or tablet build', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(isDesktopApp, isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(isDesktopApp, isFalse);
    });
  });

  group('trayIconAsset', () {
    test('Windows gets the .ico the tray plugin needs', () {
      expect(trayIconAsset(TargetPlatform.windows), endsWith('.ico'));
    });

    test('macOS and Linux get the bundled PNG logo', () {
      expect(trayIconAsset(TargetPlatform.macOS), endsWith('.png'));
      expect(trayIconAsset(TargetPlatform.linux), endsWith('.png'));
    });
  });

  group('DesktopManager', () {
    Future<_FakeNotificationService> mount(WidgetTester tester) async {
      final notifications = _FakeNotificationService();
      when(() => notifications.init()).thenAnswer((_) async {});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationServiceProvider.overrideWithValue(notifications),
          ],
          child: const MaterialApp(
            home: DesktopManager(child: Text('zedu content')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return notifications;
    }

    testWidgets('prepares close-to-tray, the tray menu and notifications', (
      tester,
    ) async {
      final notifications = await mount(tester);

      expect(find.text('zedu content'), findsOneWidget);
      expect(
        windowCalls.map((call) => call.method),
        contains('setPreventClose'),
      );
      expect(
        trayCalls.map((call) => call.method),
        containsAll(<String>['setIcon', 'setContextMenu']),
      );
      final iconCall = trayCalls.firstWhere((call) => call.method == 'setIcon');
      expect(
        iconCall.arguments.toString(),
        contains(trayIconAsset(defaultTargetPlatform)),
      );
      verify(() => notifications.init()).called(1);
    });

    testWidgets('Show Zedu restores and focuses the window', (tester) async {
      await mount(tester);
      windowCalls.clear();

      final dynamic state = tester.state(find.byType(DesktopManager));
      await state.onTrayMenuItemClick(
        MenuItem(key: 'show_window', label: 'Show Zedu'),
      );
      await tester.pump();

      expect(
        windowCalls.map((call) => call.method),
        containsAllInOrder(<String>['show', 'focus']),
      );
    });

    testWidgets('Exit turns close-to-tray off so the app really quits', (
      tester,
    ) async {
      await mount(tester);
      windowCalls.clear();

      final dynamic state = tester.state(find.byType(DesktopManager));
      await state.onTrayMenuItemClick(MenuItem(key: 'exit_app', label: 'Exit'));
      await tester.pump();

      final methods = windowCalls.map((call) => call.method).toList();
      expect(methods, contains('destroy'));
      expect(methods[methods.length - 2], 'setPreventClose');
      expect(
        windowCalls[windowCalls.length - 2].arguments.toString(),
        contains('false'),
      );
    });
  });
}
