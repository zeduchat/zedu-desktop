import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockChatHistory extends Mock implements ChatHistoryNotifier {}

class MockDraftStore extends Mock implements DmDraftStore {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

Future<void> _pumpChatArea(
  WidgetTester tester, {
  String username = 'Menu Tester',
  String? participantEmail,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final history = MockChatHistory();
  when(() => history.messages).thenReturn([]);
  when(() => history.isLoading).thenReturn(false);
  when(() => history.hasMore).thenReturn(false);
  when(() => history.loadFailed).thenReturn(false);
  when(() => history.loadMoreFailed).thenReturn(false);
  when(() => history.historyCleared).thenReturn(false);
  final drafts = MockDraftStore();
  when(() => drafts.load(any())).thenAnswer((_) async => null);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        chatHistoryProvider('chat-1').overrideWith((ref) => history),
        dmDraftStoreProvider.overrideWith((ref) => drafts),
      ],
      child: buildTestMaterialApp(
        Scaffold(
          body: DmChatArea(
            conversation: DmConversation(
              channelId: 'chat-1',
              username: username,
              participantId: 'user-1',
              participantEmail: participantEmail,
              previewMessage: '',
              unreadCount: 0,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openViewProfile(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('View profile'));
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
    );
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  testWidgets('DM menu uses a white surface and opens the selected action', (
    tester,
  ) async {
    await _pumpChatArea(tester);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();

    expect(find.text('View profile'), findsOneWidget);
    expect(find.text('Delete conversation'), findsOneWidget);
    final menuSurface = tester
        .widgetList<Material>(find.byType(Material))
        .where(
          (material) =>
              material.shape is RoundedRectangleBorder &&
              material.elevation == 8,
        );
    expect(menuSurface, hasLength(1));
    expect(menuSurface.single.color, AppPalette.light.onPrimary);
    expect(menuSurface.single.surfaceTintColor, Colors.transparent);
    expect(
      tester.widget<Text>(find.text('Delete conversation')).style?.color,
      AppPalette.light.error,
    );

    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('every menu row has a handler and no dead rows are offered', (
    tester,
  ) async {
    await _pumpChatArea(tester);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();

    final menuValues = tester
        .widgetList<PopupMenuItem<String>>(
          find.byWidgetPredicate((w) => w is PopupMenuItem<String>),
        )
        .map((item) => item.value)
        .toList();

    expect(menuValues, isNotEmpty);
    expect(menuValues, isNot(contains('block_user')));
    expect(find.text('Block User'), findsNothing);

    // Keys _handleMenuAction responds to; keep in sync with the switch.
    const handled = {
      'view_profile',
      'mute_notifications',
      'pin_conversation',
      'search_in_conversation',
      'view_files',
      'clear_history',
      'delete_conversation',
    };
    // Handled by a separate fix already in review for Ziki #2687 (PR 1296).
    const pendingElsewhere = {'pinned_messages'};

    for (final value in menuValues) {
      expect(
        handled.contains(value) || pendingElsewhere.contains(value),
        isTrue,
        reason: 'menu action "$value" has no handler in _handleMenuAction',
      );
    }
    await _unmount(tester);
  });

  group('View profile', () {
    testWidgets('shows the person without their internal user id', (
      tester,
    ) async {
      await _pumpChatArea(tester);
      await _openViewProfile(tester);

      final dialog = find.byType(Dialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Menu Tester')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('@Menu_Tester')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('M')),
        findsOneWidget,
      );
      expect(find.textContaining('user-1'), findsNothing);
      expect(find.textContaining('User ID'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('keeps a leading emoji whole in the initial', (tester) async {
      await _pumpChatArea(tester, username: '😀 Smiley');
      await _openViewProfile(tester);

      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('😀')),
        findsOneWidget,
      );
      await _unmount(tester);
    });

    testWidgets('shows the email when the conversation has one', (
      tester,
    ) async {
      await _pumpChatArea(tester, participantEmail: 'menu@zedu.chat');
      await _openViewProfile(tester);

      expect(find.text('menu@zedu.chat'), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('closes with the Close button', (tester) async {
      await _pumpChatArea(tester);
      await _openViewProfile(tester);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      await _unmount(tester);
    });
  });
}
