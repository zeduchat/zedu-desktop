import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

/// The labels in a tray menu, in order, from the arguments the app sent to
/// the tray plugin ("separator" items have no label and are skipped).
List<String> _labels(Object? arguments) {
  final labels = <String>[];
  void walk(Object? node) {
    if (node is Map) {
      final label = node['label'];
      if (label is String && label.isNotEmpty) labels.add(label);
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  walk(arguments);
  return labels;
}

void main() {
  group('buildTrayMenu', () {
    test('offers Pause notifications for 1 hour while not paused', () {
      final menu = buildTrayMenu(paused: false);
      final labels = menu.items!.map((i) => i.label).whereType<String>();

      expect(labels, ['Show Zedu', 'Pause notifications for 1 hour', 'Exit']);
      expect(
        menu.items!.map((i) => i.key),
        contains(trayPauseNotificationsKey),
      );
      expect(
        menu.items!.map((i) => i.key),
        isNot(contains(trayResumeNotificationsKey)),
      );
    });

    test('offers Resume notifications while paused', () {
      final menu = buildTrayMenu(paused: true);
      final labels = menu.items!.map((i) => i.label).whereType<String>();

      expect(labels, ['Show Zedu', 'Resume notifications', 'Exit']);
      expect(
        menu.items!.map((i) => i.key),
        contains(trayResumeNotificationsKey),
      );
      expect(
        menu.items!.map((i) => i.key),
        isNot(contains(trayPauseNotificationsKey)),
      );
    });
  });

  group('applyTrayNotificationAction', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [authNotifierProvider.overrideWith(_Auth.new)],
      );
      addTearDown(container.dispose);
    });

    NotificationSettingsNotifier notifier() =>
        container.read(notificationSettingsProvider.notifier);
    NotificationSettings settings() =>
        container.read(notificationSettingsProvider);

    test('Pause pauses notifications for one hour, as the user menu does', () {
      final before = DateTime.now();

      final handled = applyTrayNotificationAction(
        trayPauseNotificationsKey,
        notifier(),
      );

      expect(handled, isTrue);
      expect(settings().isDndActive, isTrue);
      final length = settings().dndUntil!.difference(before);
      expect(length, greaterThanOrEqualTo(trayPauseDuration));
      expect(length, lessThan(trayPauseDuration + const Duration(seconds: 5)));
    });

    test('Resume ends the pause and keeps the muted people', () {
      notifier().muteParticipant('p-1');
      notifier().setDndMode(const Duration(hours: 2));

      final handled = applyTrayNotificationAction(
        trayResumeNotificationsKey,
        notifier(),
      );

      expect(handled, isTrue);
      expect(settings().isDndActive, isFalse);
      expect(settings().isMuted('p-1'), isTrue);
    });

    test('other tray items and no key do nothing', () {
      for (final key in [trayShowWindowKey, trayExitKey, 'something', null]) {
        expect(applyTrayNotificationAction(key, notifier()), isFalse);
      }
      expect(settings().isDndActive, isFalse);
    });
  });

  group('DesktopManager tray menu', () {
    late List<List<String>> menus;

    setUp(() {
      menus = [];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('tray_manager'), (
        call,
      ) async {
        if (call.method == 'setContextMenu') {
          menus.add(_labels(call.arguments));
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (call) async => null,
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('tray_manager'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('window_manager'),
          null,
        );
      });
    });

    Future<ProviderContainer> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authNotifierProvider.overrideWith(_Auth.new)],
          child: buildTestMaterialApp(const DesktopManager(child: Text('app'))),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(DesktopManager)),
      );
    }

    testWidgets('starts with Pause while notifications are on', (tester) async {
      await pump(tester);

      expect(menus.last, [
        'Show Zedu',
        'Pause notifications for 1 hour',
        'Exit',
      ]);
    });

    testWidgets('shows Resume when the user menu pauses notifications, and '
        'Pause again when it resumes', (tester) async {
      final container = await pump(tester);
      final notifier = container.read(notificationSettingsProvider.notifier);

      notifier.setDndMode(const Duration(hours: 2));
      await tester.pumpAndSettle();
      expect(menus.last, ['Show Zedu', 'Resume notifications', 'Exit']);

      notifier.clearDndMode();
      await tester.pumpAndSettle();
      expect(menus.last, [
        'Show Zedu',
        'Pause notifications for 1 hour',
        'Exit',
      ]);
    });

    testWidgets('choosing Pause in the tray pauses, and the menu then offers '
        'Resume', (tester) async {
      final container = await pump(tester);
      final listener =
          tester.state(find.byType(DesktopManager)) as TrayListener;

      listener.onTrayMenuItemClick(
        MenuItem(
          key: trayPauseNotificationsKey,
          label: 'Pause notifications for 1 hour',
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(notificationSettingsProvider).isDndActive, isTrue);
      expect(menus.last, ['Show Zedu', 'Resume notifications', 'Exit']);

      listener.onTrayMenuItemClick(
        MenuItem(
          key: trayResumeNotificationsKey,
          label: 'Resume notifications',
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(notificationSettingsProvider).isDndActive, isFalse);
      expect(menus.last, [
        'Show Zedu',
        'Pause notifications for 1 hour',
        'Exit',
      ]);
    });

    testWidgets('goes back to Pause by itself when the hour runs out', (
      tester,
    ) async {
      final container = await pump(tester);
      final listener =
          tester.state(find.byType(DesktopManager)) as TrayListener;

      listener.onTrayMenuItemClick(
        MenuItem(
          key: trayPauseNotificationsKey,
          label: 'Pause notifications for 1 hour',
        ),
      );
      await tester.pumpAndSettle();
      expect(menus.last, ['Show Zedu', 'Resume notifications', 'Exit']);

      await tester.pump(trayPauseDuration + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(container.read(notificationSettingsProvider).isDndActive, isFalse);
      expect(menus.last, [
        'Show Zedu',
        'Pause notifications for 1 hour',
        'Exit',
      ]);
    });
  });
}
