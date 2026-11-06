import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockChannelRepository extends Mock implements ChannelRepository {}

class FakeChatHistoryNotifier extends ChangeNotifier
    implements ChatHistoryNotifier {
  FakeChatHistoryNotifier(this.channelId);

  @override
  final String channelId;

  @override
  List<Map<String, dynamic>> messages = [];

  @override
  String get currentUserName => 'Test User';

  @override
  String? get currentUserAvatarUrl => null;

  String? retriedMessageId;

  @override
  Future<void> retryMessage(String messageId) async {
    retriedMessageId = messageId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockChannelRepository repository;
  late FakeChatHistoryNotifier fakeChatHistory;

  setUp(() {
    repository = MockChannelRepository();
    fakeChatHistory = FakeChatHistoryNotifier('ch-1');
  });

  Future<void> pumpList(
    WidgetTester tester,
    Result<List<ChannelMessage>> r, {
    FakeChatHistoryNotifier? chatNotifier,
  }) {
    when(
      () => repository.fetchChannelMessages('ch-1'),
    ).thenAnswer((_) async => r);
    return tester
        .pumpWidget(
          ProviderScope(
            overrides: [
              channelRepositoryProvider.overrideWithValue(repository),
              chatHistoryProvider.overrideWith(
                (ref, channelId) => chatNotifier ?? fakeChatHistory,
              ),
            ],
            retry: (_, _) => null,
            child: buildTestMaterialApp(
              const Scaffold(
                body: ChannelMessageList(
                  channelId: 'ch-1',
                  empty: Text('Welcome to #general'),
                ),
              ),
            ),
          ),
        )
        .then((_) => tester.pumpAndSettle());
  }

  testWidgets('shows the messages, newest at the bottom', (tester) async {
    await pumpList(
      tester,
      const Success([
        ChannelMessage(senderName: 'gold', text: 'newest'),
        ChannelMessage(senderName: 'Ada', text: 'oldest'),
      ]),
    );

    expect(find.text('Welcome to #general'), findsNothing);
    expect(
      tester.getTopLeft(find.text('oldest')).dy,
      lessThan(tester.getTopLeft(find.text('newest')).dy),
    );
  });

  testWidgets('opens a URL in a message when it is tapped', (tester) async {
    final opened = <Uri>[];
    final original = messageLinkLauncher;
    messageLinkLauncher = (uri) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => messageLinkLauncher = original);

    await pumpList(
      tester,
      const Success([
        ChannelMessage(senderName: 'Ada', text: 'https://example.com/channel'),
      ]),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(SelectableText)) + const Offset(20, 8),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(opened, [Uri.parse('https://example.com/channel')]);
  });

  testWidgets('shows the welcome screen when empty', (tester) async {
    await pumpList(tester, const Success(<ChannelMessage>[]));

    expect(find.text('Welcome to #general'), findsOneWidget);
  });

  testWidgets('offers a retry when loading fails', (tester) async {
    await pumpList(tester, const Failure(ApiFailure(message: 'boom')));

    expect(find.text("Couldn't load messages. Retry"), findsOneWidget);
  });

  testWidgets(
    'renders placeholder initial for empty senderName without crashing',
    (tester) async {
      await pumpList(
        tester,
        const Success([ChannelMessage(senderName: '', text: 'empty sender')]),
      );

      expect(find.text('?'), findsOneWidget);
      expect(find.text('empty sender'), findsOneWidget);
    },
  );

  testWidgets(
    'shows sending indicator for optimistic pending channel message (#2571)',
    (tester) async {
      fakeChatHistory.messages = [
        {
          'id': 'temp-1',
          'content': 'Sending channel message',
          'channel_id': 'ch-1',
          'status': 'sending',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      await pumpList(tester, const Success(<ChannelMessage>[]));

      expect(find.text('Sending channel message'), findsOneWidget);
      expect(find.text('Sending...'), findsOneWidget);
    },
  );

  testWidgets(
    'shows failed indicator and invokes retryMessage on tap (#2571)',
    (tester) async {
      fakeChatHistory.messages = [
        {
          'id': 'failed-msg-1',
          'content': 'Failed channel message',
          'channel_id': 'ch-1',
          'status': 'failed',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      await pumpList(tester, const Success(<ChannelMessage>[]));

      expect(find.text('Failed channel message'), findsOneWidget);
      expect(find.text('Failed – Tap to retry'), findsOneWidget);

      await tester.tap(find.text('Failed – Tap to retry'));
      expect(fakeChatHistory.retriedMessageId, 'failed-msg-1');
    },
  );

  group('Copy text', () {
    late List<String> copied;

    setUp(() {
      copied = [];
    });

    Future<void> mockClipboard(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    Future<void> rightClick(WidgetTester tester, Finder target) async {
      final gesture = await tester.startGesture(
        tester.getCenter(target),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    }

    // On a desktop the message text has its own right-click menu (Select
    // all, Copy). That menu has to carry Copy text as well.
    testWidgets('right-clicking the text offers Copy text and copies the '
        'plain text', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await mockClipboard(tester);
        await pumpList(
          tester,
          const Success([
            ChannelMessage(senderName: 'Ada', text: 'Ship **it** today'),
          ]),
        );

        await rightClick(tester, find.byType(SelectableText));
        expect(find.text('Copy text'), findsOneWidget);

        await tester.tap(find.text('Copy text'));
        await tester.pump();

        expect(copied, ['Ship it today']);
        expect(find.text('Copied'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('right-clicking beside the text offers Copy text too', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await mockClipboard(tester);
        await pumpList(
          tester,
          const Success([ChannelMessage(senderName: 'Ada', text: 'hello')]),
        );

        await rightClick(tester, find.byType(CircleAvatar));
        expect(find.text('Copy text'), findsOneWidget);

        await tester.tap(find.text('Copy text'));
        await tester.pump();

        expect(copied, ['hello']);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('hovering a message shows an actions button with Copy text', (
      tester,
    ) async {
      await mockClipboard(tester);
      await pumpList(
        tester,
        const Success([ChannelMessage(senderName: 'Ada', text: 'hello')]),
      );
      expect(find.byTooltip('Message actions'), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(ChannelMessageTile)));
      await tester.pump();

      await tester.tap(find.byTooltip('Message actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy text'));
      await tester.pump();

      expect(copied, ['hello']);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('does not copy an empty message', (tester) async {
      await mockClipboard(tester);
      await pumpList(
        tester,
        const Success([ChannelMessage(senderName: 'Ada', text: '   ')]),
      );

      await rightClick(tester, find.byType(ChannelMessageTile));
      await tester.tap(find.text('Copy text'));
      await tester.pump();

      expect(copied, isEmpty);
      expect(find.text('Copied'), findsNothing);
    });
  });

  test('channelMessagePlainText drops the Markdown marks', () {
    expect(channelMessagePlainText('a **b** c'), 'a b c');
  });

  group('day dividers', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 0, 1);
    final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
    final older = DateTime(now.year, now.month, now.day - 10, 9);

    testWidgets('one divider above the first message of each day', (
      tester,
    ) async {
      await pumpList(
        tester,
        Success([
          ChannelMessage(senderName: 'Ada', text: 'today', createdAt: today),
          ChannelMessage(
            senderName: 'Ada',
            text: 'yesterday late',
            createdAt: yesterday.add(const Duration(hours: 2)),
          ),
          ChannelMessage(
            senderName: 'Ada',
            text: 'yesterday',
            createdAt: yesterday,
          ),
          ChannelMessage(
            senderName: 'Ada',
            text: 'old later',
            createdAt: older.add(const Duration(hours: 5)),
          ),
          ChannelMessage(senderName: 'Ada', text: 'old', createdAt: older),
        ]),
      );

      expect(find.byType(ChannelDayDivider), findsNWidgets(3));
      final olderLabel = channelDayLabel(older);
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      for (final (label, first, last) in [
        (olderLabel, 'old', 'old later'),
        ('Yesterday', 'yesterday', 'yesterday late'),
        ('Today', 'today', 'today'),
      ]) {
        expect(find.text(label), findsOneWidget);
        expect(top(label), lessThan(top(first)));
        expect(top(label), lessThanOrEqualTo(top(last)));
      }
      expect(top(olderLabel), lessThan(top('Yesterday')));
      expect(top('old later'), lessThan(top('Yesterday')));
      expect(top('Yesterday'), lessThan(top('Today')));
    });

    testWidgets('no divider for messages without a time', (tester) async {
      await pumpList(
        tester,
        const Success([ChannelMessage(senderName: 'Ada', text: 'undated')]),
      );

      expect(find.byType(ChannelDayDivider), findsNothing);
    });
  });

  group('channelDayLabel', () {
    final now = DateTime(2026, 11, 4, 9); // A Wednesday.

    test('today and yesterday by calendar day, not 24 hours', () {
      expect(channelDayLabel(DateTime(2026, 11, 4, 0, 1), now: now), 'Today');
      expect(
        channelDayLabel(DateTime(2026, 11, 3, 23, 59), now: now),
        'Yesterday',
      );
    });

    test('the weekday within the last week', () {
      expect(channelDayLabel(DateTime(2026, 11, 2), now: now), 'Monday');
      expect(channelDayLabel(DateTime(2026, 10, 29), now: now), 'Thursday');
    });

    test('the date from a week ago, with the year only when not this year', () {
      expect(
        channelDayLabel(DateTime(2026, 10, 28), now: now),
        'Wednesday, Oct 28',
      );
      expect(
        channelDayLabel(DateTime(2025, 12, 31), now: now),
        'Wednesday, Dec 31, 2025',
      );
    });
  });
}
