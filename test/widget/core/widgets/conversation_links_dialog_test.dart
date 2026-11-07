import 'dart:async';

import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

void main() {
  ConversationLinkSource source(
    String content, {
    required String author,
    required String sentAt,
  }) => ConversationLinkSource(
    content: content,
    author: author,
    sharedAt: DateTime.parse(sentAt),
  );

  test('buildConversationLinks keeps the newest share of each URL', () {
    final links = buildConversationLinks([
      source(
        'old https://zedu.chat/docs',
        author: 'Ada',
        sentAt: '2026-11-01T09:00:00Z',
      ),
      source(
        'new https://zedu.chat/docs and https://github.com/zeduchat',
        author: 'Bola',
        sentAt: '2026-11-02T09:00:00Z',
      ),
    ]);

    expect(links.map((link) => link.uri.toString()), [
      'https://zedu.chat/docs',
      'https://github.com/zeduchat',
    ]);
    expect(links.first.author, 'Bola');
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    Iterable<ConversationLinkSource> messages = const [],
    Future<List<ConversationLinkSource>> Function()? loadMessages,
    Future<bool> Function(String)? onOpen,
  }) async {
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: ConversationLinksDialog(
            title: 'Shared links',
            messages: messages,
            loadMessages: loadMessages,
            onOpen: onOpen,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the empty state when no links were shared', (
    tester,
  ) async {
    await pumpDialog(tester);

    expect(
      find.text('No links shared in this conversation yet.'),
      findsOneWidget,
    );
  });

  testWidgets('renders link details and opens the selected safe URL', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpDialog(
      tester,
      messages: [
        source(
          '<a href="https://zedu.chat/roadmap">Roadmap</a>',
          author: 'Ada',
          sentAt: '2026-11-01T09:00:00Z',
        ),
      ],
      onOpen: (link) async {
        opened.add(link);
        return true;
      },
    );

    expect(find.text('https://zedu.chat/roadmap'), findsOneWidget);
    expect(find.textContaining('Ada ·'), findsOneWidget);
    await tester.tap(find.text('https://zedu.chat/roadmap'));
    await tester.pump();

    expect(opened, ['https://zedu.chat/roadmap']);
  });

  testWidgets('shows loading and retry states', (tester) async {
    final firstLoad = Completer<List<ConversationLinkSource>>();
    var attempts = 0;
    await pumpDialog(
      tester,
      loadMessages: () async {
        attempts++;
        if (attempts == 1) return firstLoad.future;
        return [
          source(
            'https://zedu.chat/recovered',
            author: 'Ada',
            sentAt: '2026-11-01T09:00:00Z',
          ),
        ];
      },
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    firstLoad.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load links."), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('https://zedu.chat/recovered'), findsOneWidget);
  });
}
