import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _Auth extends AuthNotifier {
  _Auth(this.status);

  final AuthStatus status;

  @override
  AuthState build() => AuthState(status: status);
}

class _Channels extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('c-general', 'general'),
    _channel('c-old', 'old-launch', archived: true),
  ];
}

class _Dms extends DmListNotifier {
  @override
  Future<List<DmConversation>> build() async => [
    DmConversation(
      channelId: 'c-gideon',
      username: 'Gideon',
      participantId: 'p-gideon',
      previewMessage: '',
      unreadCount: 0,
    ),
  ];
}

class _FailingChannels extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => throw Exception('offline');
}

class _PendingChannels extends ChannelNotifier {
  _PendingChannels(this.result);

  final Completer<List<Channel>> result;

  @override
  Future<List<Channel>> build() => result.future;
}

/// The real notifier follows the selected workspace, which loads from the API.
class _ActiveChat extends ActiveChatNotifier {
  @override
  ActiveChatState build() => ActiveChatState.channelDirectory;
}

Channel _channel(String id, String name, {bool archived = false}) => Channel(
  id: id,
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'owner',
  archived: archived,
);

GoRouter _router({required bool withTextField}) => GoRouter(
  initialLocation: '/settings',
  routes: [
    GoRoute(
      path: AppRouter.home,
      builder: (_, _) => const Scaffold(body: Text('home screen')),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => Scaffold(
        body: withTextField
            ? const TextField(autofocus: true)
            : const Text('settings screen'),
      ),
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  AuthStatus status = AuthStatus.authenticated,
  bool withTextField = true,
  bool channelsFail = false,
  Completer<List<Channel>>? pendingChannels,
}) async {
  final router = _router(withTextField: withTextField);
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _Auth(status)),
      channelProvider.overrideWith(
        pendingChannels != null
            ? () => _PendingChannels(pendingChannels)
            : channelsFail
            ? _FailingChannels.new
            : _Channels.new,
      ),
      dmListProvider.overrideWith(_Dms.new),
      activeChatProvider.overrideWith(_ActiveChat.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => QuickSwitcherShortcut(
          router: router,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _pressCtrlK(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _pressCtrlSlash(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.slash);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  group('Keyboard shortcuts list', () {
    testWidgets('Ctrl+/ opens it, even with a text field focused', (
      tester,
    ) async {
      await _pump(tester);

      await _pressCtrlSlash(tester);

      expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.text('Jump to a channel or conversation'), findsOneWidget);
      expect(find.text('Bold'), findsOneWidget);
    });

    testWidgets('Cmd+/ opens it', (tester) async {
      await _pump(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);
    });

    testWidgets('Escape closes it', (tester) async {
      await _pump(tester);
      await _pressCtrlSlash(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardShortcutsDialog), findsNothing);
    });

    testWidgets('the close button closes it', (tester) async {
      await _pump(tester);
      await _pressCtrlSlash(tester);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(KeyboardShortcutsDialog), findsNothing);
    });

    testWidgets('pressing it again does not open a second list', (
      tester,
    ) async {
      await _pump(tester);

      await _pressCtrlSlash(tester);
      await _pressCtrlSlash(tester);

      expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);
    });

    testWidgets('does not open over the quick switcher', (tester) async {
      await _pump(tester);

      await _pressCtrlK(tester);
      await _pressCtrlSlash(tester);

      expect(find.byType(QuickSwitcherDialog), findsOneWidget);
      expect(find.byType(KeyboardShortcutsDialog), findsNothing);
    });

    testWidgets('does nothing when signed out', (tester) async {
      await _pump(tester, status: AuthStatus.unauthenticated);

      await _pressCtrlSlash(tester);

      expect(find.byType(KeyboardShortcutsDialog), findsNothing);
    });

    for (final (platform, modifier, other) in [
      (TargetPlatform.windows, 'Ctrl', 'Cmd'),
      (TargetPlatform.linux, 'Ctrl', 'Cmd'),
      (TargetPlatform.macOS, 'Cmd', 'Ctrl'),
    ]) {
      testWidgets('shows $modifier on ${platform.name}', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const KeyboardShortcutsDialog(),
          ),
        );

        expect(find.text(modifier), findsWidgets);
        expect(find.text(other), findsNothing);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('fits and scrolls in a short window', (tester) async {
      tester.view.physicalSize = const Size(640, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const KeyboardShortcutsDialog(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('QuickSwitcherShortcut', () {
    testWidgets(
      'Ctrl+K opens the switcher with channels and DMs, not archived channels',
      (tester) async {
        await _pump(tester);

        await _pressCtrlK(tester);

        expect(find.byType(QuickSwitcherDialog), findsOneWidget);
        expect(find.text('general'), findsOneWidget);
        expect(find.text('Gideon'), findsOneWidget);
        expect(find.text('old-launch'), findsNothing);
      },
    );

    testWidgets('picking a channel opens it and goes home', (tester) async {
      final container = await _pump(tester);

      await _pressCtrlK(tester);
      await tester.tap(find.text('general'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickSwitcherDialog), findsNothing);
      expect(container.read(homeSidebarProvider), HomeSidebarType.home);
      expect(container.read(activeChatProvider).id, 'general');
      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('picking a DM opens it in the DMs tab', (tester) async {
      final container = await _pump(tester);

      await _pressCtrlK(tester);
      await tester.tap(find.text('Gideon'));
      await tester.pumpAndSettle();

      expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
      expect(container.read(selectedDmProvider)?.username, 'Gideon');
      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('does nothing when signed out', (tester) async {
      await _pump(tester, status: AuthStatus.unauthenticated);

      await _pressCtrlK(tester);

      expect(find.byType(QuickSwitcherDialog), findsNothing);
    });

    testWidgets('a second Ctrl+K while it is open does not stack another', (
      tester,
    ) async {
      await _pump(tester);

      await _pressCtrlK(tester);
      await _pressCtrlK(tester);

      expect(find.byType(QuickSwitcherDialog), findsOneWidget);
    });

    testWidgets('tells the user when the channels could not be loaded', (
      tester,
    ) async {
      await _pump(tester, channelsFail: true);

      await _pressCtrlK(tester);

      expect(find.byType(QuickSwitcherDialog), findsOneWidget);
      expect(find.text('Gideon'), findsOneWidget);
      expect(
        find.text("Couldn't load all your channels and DMs."),
        findsOneWidget,
      );

      // Let the toast close itself before the test ends.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('opens at once and fills in when the channels arrive', (
      tester,
    ) async {
      final channels = Completer<List<Channel>>();
      await _pump(tester, pendingChannels: channels);

      await _pressCtrlK(tester);

      expect(find.byType(QuickSwitcherDialog), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
      expect(find.text('Gideon'), findsOneWidget);
      expect(find.text('general'), findsNothing);

      channels.complete([_channel('c-general', 'general')]);
      await tester.pumpAndSettle();

      expect(find.text('Loading…'), findsNothing);
      expect(find.text('general'), findsOneWidget);
      expect(find.text('Gideon'), findsOneWidget);
    });

    testWidgets('a query typed while loading applies to what arrives', (
      tester,
    ) async {
      final channels = Completer<List<Channel>>();
      await _pump(tester, pendingChannels: channels);
      await _pressCtrlK(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(QuickSwitcherDialog),
          matching: find.byType(TextField),
        ),
        'gen',
      );
      await tester.pump();
      expect(find.text('Loading…'), findsOneWidget);
      expect(find.text('No matches'), findsNothing);

      channels.complete([_channel('c-general', 'general')]);
      await tester.pumpAndSettle();

      expect(find.text('general'), findsOneWidget);
      expect(find.text('Gideon'), findsNothing);
    });

    testWidgets('entries arriving keep the highlight on the same row', (
      tester,
    ) async {
      final channels = Completer<List<Channel>>();
      final container = await _pump(tester, pendingChannels: channels);
      await _pressCtrlK(tester);

      // Gideon is highlighted; the channels arrive above it.
      channels.complete([_channel('c-general', 'general')]);
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(container.read(selectedDmProvider)?.channelId, 'c-gideon');
    });

    testWidgets('fires when nothing on the screen has focus', (tester) async {
      await _pump(tester, withTextField: false);
      // No text field or other control holds focus, only the page itself.
      expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());

      await _pressCtrlK(tester);

      expect(find.byType(QuickSwitcherDialog), findsOneWidget);
    });
  });
}
