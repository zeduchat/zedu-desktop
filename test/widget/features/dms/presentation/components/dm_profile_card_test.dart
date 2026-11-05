import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockChatHistory extends Mock implements ChatHistoryNotifier {}

class MockDraftStore extends Mock implements DmDraftStore {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

final _conversation = DmConversation(
  channelId: 'chat-1',
  username: 'Card Tester',
  participantId: 'user-1',
  previewMessage: '',
  unreadCount: 0,
);

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

  testWidgets('View Profile calls onViewProfile', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: DmProfileCard(
            conversation: _conversation,
            onViewProfile: () => opened++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('View Profile'));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('View Profile on the DM intro card opens the profile', (
    tester,
  ) async {
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
          Scaffold(body: DmChatArea(conversation: _conversation)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('View Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Card Tester'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
