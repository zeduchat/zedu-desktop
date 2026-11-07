import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

/// Serves and records thread replies without a server.
class _FakeDmRepository extends DmRepository {
  _FakeDmRepository() : super(MockApiBaseService());

  List<Map<String, dynamic>> replies = [];
  final sent = <({String channelId, String threadId, String content})>[];
  bool failLoad = false;
  bool failSend = false;

  @override
  Future<List<Map<String, dynamic>>> getThreadReplies({
    required String channelId,
    required String threadId,
  }) async {
    if (failLoad) throw const ApiFailure(message: 'boom');
    return replies;
  }

  @override
  Future<void> replyToThread({
    required String channelId,
    required String threadId,
    required String content,
  }) async {
    if (failSend) throw const ApiFailure(message: 'boom');
    sent.add((channelId: channelId, threadId: threadId, content: content));
    replies = [
      ...replies,
      {
        'id': 'r${replies.length + 1}',
        'username': 'Me',
        'content': content,
        'created_at': '2026-11-05T10:00:00Z',
      },
    ];
  }
}

void main() {
  Future<_FakeDmRepository> pumpPanel(
    WidgetTester tester, {
    List<Map<String, dynamic>> replies = const [],
    bool failLoad = false,
  }) async {
    final repository = _FakeDmRepository()
      ..replies = replies
      ..failLoad = failLoad;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dmRepositoryProvider.overrideWithValue(repository)],
        child: buildTestMaterialApp(
          Scaffold(
            body: ThreadPanel(
              channelId: 'chat-1',
              threadId: 'thread-1',
              parentMessage: 'Parent message',
              parentAuthor: 'Ada',
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('loads the replies saved on the server', (tester) async {
    await pumpPanel(
      tester,
      replies: [
        {
          'id': 'r1',
          'username': 'Bayo',
          'content': '<p>On it</p>',
          'created_at': '2026-11-05T09:00:00Z',
        },
      ],
    );

    expect(find.text('1 reply'), findsOneWidget);
    expect(find.text('Bayo'), findsOneWidget);
    expect(find.text('On it', findRichText: true), findsOneWidget);
  });

  testWidgets('send icon posts the reply to this thread and shows it', (
    tester,
  ) async {
    final repository = await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), '  Reply via icon  ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(repository.sent, [
      (channelId: 'chat-1', threadId: 'thread-1', content: 'Reply via icon'),
    ]);
    expect(find.text('Reply via icon', findRichText: true), findsOneWidget);
    expect(find.text('1 reply'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('Enter submits and clears the reply field', (tester) async {
    final repository = await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), 'Reply via keyboard');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.sent.single.content, 'Reply via keyboard');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('whitespace-only reply is not sent', (tester) async {
    final repository = await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(repository.sent, isEmpty);
    expect(find.text('0 replies'), findsOneWidget);
  });

  testWidgets('a failed send keeps the text and says so', (tester) async {
    final repository = await pumpPanel(tester);
    repository.failSend = true;

    await tester.enterText(find.byType(TextField), 'Keep me');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't send your reply. Try again."), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'Keep me');
  });

  testWidgets('a failed load offers a retry', (tester) async {
    final repository = await pumpPanel(tester, failLoad: true);
    expect(find.text("Couldn't load replies."), findsOneWidget);

    repository.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load replies."), findsNothing);
    expect(find.text('0 replies'), findsOneWidget);
  });
}
