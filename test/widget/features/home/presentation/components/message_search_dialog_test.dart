import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

/// Records each query and answers with [results], or with [pages] (page 1
/// first) when set.
class _FakeSearchService implements MessageSearchService {
  final queries = <String>[];
  final requestedPages = <int>[];
  List<SearchResultModel> results = const [];
  List<List<SearchResultModel>>? pages;
  Object? error;

  @override
  Future<MessageSearchPage> search({
    required String orgId,
    required String query,
    int page = 1,
  }) async {
    queries.add(query);
    requestedPages.add(page);
    if (error != null) throw error!;
    final paged = pages;
    if (paged == null) {
      return MessageSearchPage(results: results, hasMore: false);
    }
    return MessageSearchPage(
      results: paged[page - 1],
      hasMore: page < paged.length,
    );
  }
}

void main() {
  late _FakeSearchService service;
  SearchResultModel? opened;

  final hit = SearchResultModel(
    id: 'm1',
    content: 'The deploy is done',
    channelId: 'c1',
    channelName: 'general',
    senderName: 'Ada Lovelace',
    createdAt: DateTime(2026, 11, 4, 9, 5),
  );

  setUp(() {
    service = _FakeSearchService();
    opened = null;
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageSearchServiceProvider.overrideWithValue(service),
          creditsOrgIdProvider.overrideWithValue('org-1'),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MessageSearchDialog(
                    people: const ['Ada Lovelace', 'Grace Hopper'],
                    channels: const [
                      MessageSearchChannelOption(id: 'c1', name: 'general'),
                      MessageSearchChannelOption(id: 'c2', name: 'design'),
                    ],
                    debounce: Duration.zero,
                    onOpenResult: (result) => opened = result,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, Key chip, String option) async {
    await tester.tap(find.byKey(chip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  group('MessageSearchDialog (#2825)', () {
    testWidgets('asks for words or a filter before searching', (tester) async {
      await openDialog(tester);
      expect(
        find.text('Type to search, or pick From, In or Date to narrow it.'),
        findsOneWidget,
      );
      expect(service.queries, isEmpty);
    });

    testWidgets('searches as you type and shows the results', (tester) async {
      service.results = [hit];
      await openDialog(tester);

      await tester.enterText(
        find.byKey(const Key('message-search-field')),
        'Deploy',
      );
      await tester.pumpAndSettle();

      expect(service.queries.last, 'deploy');
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('The deploy is done'), findsOneWidget);
      expect(find.textContaining('in #general'), findsOneWidget);
    });

    testWidgets('From, In and Date narrow the search', (tester) async {
      await openDialog(tester);
      await tester.enterText(
        find.byKey(const Key('message-search-field')),
        'deploy',
      );
      await tester.pumpAndSettle();

      await pick(tester, const Key('message-search-from'), 'Grace Hopper');
      expect(service.queries.last, 'deploy from:"Grace Hopper"');
      expect(find.text('From: Grace Hopper'), findsOneWidget);

      await pick(tester, const Key('message-search-in'), '#design');
      expect(service.queries.last, 'deploy from:"Grace Hopper" in:design');
      expect(find.text('In: #design'), findsOneWidget);

      await pick(tester, const Key('message-search-date'), 'Today');
      expect(
        service.queries.last,
        startsWith('deploy from:"Grace Hopper" in:design on:'),
      );
      expect(find.text('Clear 3 filters'), findsOneWidget);
    });

    testWidgets('a filter alone searches, and Clear removes every filter', (
      tester,
    ) async {
      await openDialog(tester);

      await pick(tester, const Key('message-search-in'), '#general');
      expect(service.queries.last, 'in:general');
      expect(
        find.text('No messages match. Try removing a filter.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('message-search-clear')));
      await tester.pumpAndSettle();
      expect(find.text('In'), findsOneWidget);
      expect(find.byKey(const Key('message-search-clear')), findsNothing);
    });

    testWidgets('picking a result closes the dialog and opens it', (
      tester,
    ) async {
      service.results = [hit];
      await openDialog(tester);
      await tester.enterText(
        find.byKey(const Key('message-search-field')),
        'deploy',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('The deploy is done'));
      await tester.pumpAndSettle();

      expect(opened?.id, 'm1');
      expect(find.byType(MessageSearchDialog), findsNothing);
    });

    testWidgets('Load more adds the next page, newest first (#12405)', (
      tester,
    ) async {
      SearchResultModel result(String id, int day) => SearchResultModel(
        id: id,
        content: 'message $id',
        channelId: 'c1',
        channelName: 'general',
        senderName: 'Ada Lovelace',
        createdAt: DateTime(2026, 11, day),
      );
      service.pages = [
        [result('m1', 20), result('m2', 18)],
        // m2 again, as when a new message shifts the pages.
        [result('m2', 18), result('m3', 19), result('m4', 1)],
      ];
      await openDialog(tester);
      await tester.enterText(
        find.byKey(const Key('message-search-field')),
        'deploy',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('message-search-load-more')), findsOneWidget);

      await tester.tap(find.byKey(const Key('message-search-load-more')));
      await tester.pumpAndSettle();

      expect(service.requestedPages, [1, 2]);
      expect(service.queries.toSet(), {'deploy'});
      final shown = tester
          .widgetList<Text>(find.textContaining('message m'))
          .map((text) => text.data)
          .toList();
      expect(shown, ['message m1', 'message m3', 'message m2', 'message m4']);
      expect(find.byKey(const Key('message-search-load-more')), findsNothing);
    });

    testWidgets('a failed search offers to try again', (tester) async {
      service.error = const ApiFailure(message: 'Down', statusCode: 500);
      await openDialog(tester);
      await tester.enterText(
        find.byKey(const Key('message-search-field')),
        'deploy',
      );
      await tester.pumpAndSettle();
      expect(find.text("Couldn't search messages."), findsOneWidget);

      service
        ..error = null
        ..results = [hit];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('The deploy is done'), findsOneWidget);
    });
  });
}
