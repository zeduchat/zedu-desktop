import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockChatHistory extends Mock implements ChatHistoryNotifier {}

class MockDraftStore extends Mock implements DmDraftStore {}

class MockApiBaseService extends Mock implements ApiBaseService {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

/// Answers searches from a fixed list, or fails when [fail] is set.
class _FakeDmRepository extends DmRepository {
  _FakeDmRepository() : super(MockApiBaseService());

  final searches = <({String channelId, String query})>[];
  List<ConversationSearchHit> hits = const [];
  bool fail = false;

  @override
  Future<List<ConversationSearchHit>> searchMessages({
    required String channelId,
    required String query,
  }) async {
    searches.add((channelId: channelId, query: query));
    if (fail) throw const ApiFailure(message: 'boom');
    return hits;
  }
}

final _today = DateTime.now();

Future<_FakeDmRepository> _openSearch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final history = MockChatHistory();
  when(() => history.messages).thenReturn(const []);
  when(() => history.isLoading).thenReturn(false);
  when(() => history.hasMore).thenReturn(false);
  when(() => history.loadFailed).thenReturn(false);
  when(() => history.loadMoreFailed).thenReturn(false);
  when(() => history.historyCleared).thenReturn(false);
  when(() => history.currentUserName).thenReturn('Me');
  when(() => history.isMyMessage(any())).thenReturn(false);
  final drafts = MockDraftStore();
  when(() => drafts.load(any())).thenAnswer((_) async => null);
  // Closing the panel puts the cursor back in the message box, and the
  // composer saves its draft whenever the field changes.
  when(() => drafts.save(any(), any())).thenAnswer((_) async {});
  final repository = _FakeDmRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        chatHistoryProvider('chat-1').overrideWith((ref) => history),
        dmDraftStoreProvider.overrideWith((ref) => drafts),
        dmRepositoryProvider.overrideWithValue(repository),
      ],
      child: buildTestMaterialApp(
        Scaffold(
          body: DmChatArea(
            conversation: DmConversation(
              channelId: 'chat-1',
              username: 'Ada Obi',
              participantId: 'user-1',
              previewMessage: '',
              unreadCount: 0,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Search in conversation'));
  await tester.pumpAndSettle();
  return repository;
}

Finder get _searchField => find.descendant(
  of: find.byType(SearchPanel),
  matching: find.byType(TextField),
);

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(_searchField, query);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

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

  group('Search in conversation', () {
    testWidgets('opens the search panel beside the messages', (tester) async {
      await _openSearch(tester);

      expect(find.byType(SearchPanel), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Enter a search term'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('searches this conversation on the server', (tester) async {
      final repository = await _openSearch(tester);
      repository.hits = [
        ConversationSearchHit(
          messageId: 'm1',
          text: 'The budget review is on Friday',
          userName: 'Ada Obi',
          sentAt: DateTime(_today.year, _today.month, _today.day, 16, 5),
        ),
      ];

      await _search(tester, 'budget');

      expect(repository.searches, [(channelId: 'chat-1', query: 'budget')]);
      expect(
        find.text('The budget review is on Friday', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Ada Obi · 4:05 PM'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('says nothing matched instead of showing a blank list', (
      tester,
    ) async {
      await _openSearch(tester);

      await _search(tester, 'zzzz');

      expect(find.text('No messages match "zzzz"'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('shows an error with a retry when the search fails', (
      tester,
    ) async {
      final repository = await _openSearch(tester);
      repository.fail = true;

      await _search(tester, 'budget');
      expect(find.text("Couldn't search messages."), findsOneWidget);

      repository.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(repository.searches, hasLength(2));
      expect(find.text('No messages match "budget"'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('closes the panel', (tester) async {
      await _openSearch(tester);

      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchPanel), findsNothing);
      await _unmount(tester);
    });
  });
}
