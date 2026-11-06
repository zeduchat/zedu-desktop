import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

class MockSavedRepository extends Mock implements SavedRepository {}

class MockReminderRepository extends Mock implements ReminderRepository {}

final _now = DateTime(2026, 11, 6, 10);

SavedMessage row({
  required String id,
  String author = 'Ada',
  String content = 'Deadline is Friday',
  String channelName = 'general',
  String channelType = 'public',
  DateTime? savedAt,
}) => SavedMessage(
  id: id,
  target: SavedTarget(channelId: 'chan-$id', threadId: 'thread-$id'),
  kind: SavedMessageKind.thread,
  authorName: author,
  content: content,
  conversationName: channelName,
  channelType: channelType,
  savedAt: savedAt ?? _now.subtract(const Duration(hours: 1)),
);

MessageReminder reminderFor(String id, DateTime remindAt) => MessageReminder(
  id: 'rem-$id',
  channelId: 'chan-$id',
  threadId: 'thread-$id',
  remindAt: remindAt,
);

void main() {
  late MockSavedRepository repository;
  late MockReminderRepository reminderRepository;

  setUp(() {
    repository = MockSavedRepository();
    reminderRepository = MockReminderRepository();
  });

  Future<void> pumpView(
    WidgetTester tester, {
    List<SavedMessage>? items,
    List<MessageReminder> pending = const [],
    Object? error,
  }) async {
    if (error != null) {
      when(
        () => repository.list(orgId: any(named: 'orgId')),
      ).thenThrow(error);
    } else {
      when(
        () => repository.list(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => items ?? []);
    }
    when(
      () => reminderRepository.list(orgId: any(named: 'orgId')),
    ).thenAnswer((_) async => pending);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedRepositoryProvider.overrideWithValue(repository),
          reminderRepositoryProvider.overrideWithValue(reminderRepository),
          currentOrgIdProvider.overrideWithValue('org-1'),
        ],
        child: buildTestMaterialApp(SavedView(now: _now)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists saved messages with author, conversation and preview', (
    tester,
  ) async {
    await pumpView(
      tester,
      items: [
        row(id: '1', author: 'Ada', content: 'Deadline is Friday'),
        row(
          id: '2',
          author: 'Grace',
          channelName: 'Grace Hopper',
          channelType: 'dm',
          content: 'Here is the link',
        ),
      ],
    );

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Deadline is Friday'), findsOneWidget);
    // A channel keeps its hash; a direct message does not get one.
    expect(find.text('#general'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsOneWidget);
  });

  testWidgets('shows the reminder time on the row', (tester) async {
    await pumpView(
      tester,
      items: [row(id: '1')],
      pending: [reminderFor('1', DateTime(2026, 11, 6, 15, 30))],
    );

    expect(
      find.textContaining('Reminder:'),
      findsOneWidget,
      reason: 'the reminder the server holds has to be visible on the row',
    );
    expect(find.textContaining('Today'), findsWidgets);
  });

  testWidgets('a reminder already past is labelled Due and sorts to the top', (
    tester,
  ) async {
    await pumpView(
      tester,
      items: [
        row(
          id: 'recent',
          author: 'Grace',
          savedAt: _now.subtract(const Duration(minutes: 5)),
        ),
        row(
          id: 'due',
          author: 'Ada',
          savedAt: _now.subtract(const Duration(days: 3)),
        ),
      ],
      pending: [
        reminderFor('due', _now.subtract(const Duration(hours: 2))),
      ],
    );

    expect(find.text('Due'), findsOneWidget);

    final dueY = tester.getTopLeft(find.text('Ada')).dy;
    final otherY = tester.getTopLeft(find.text('Grace')).dy;
    expect(
      dueY,
      lessThan(otherY),
      reason: 'the row the user has already been reminded about comes first',
    );
  });

  testWidgets('says so when nothing is saved', (tester) async {
    await pumpView(tester, items: []);

    expect(find.text('Nothing saved yet.'), findsOneWidget);
    expect(find.text('Save a message to find it here.'), findsOneWidget);
  });

  testWidgets('reports a failure to load instead of looking empty', (
    tester,
  ) async {
    await pumpView(tester, error: Exception('offline'));

    expect(find.text('Could not load your saved messages.'), findsOneWidget);
    expect(find.text('Nothing saved yet.'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('each row offers Remove from saved and Remind me', (
    tester,
  ) async {
    await pumpView(tester, items: [row(id: '1')]);

    await tester.tap(find.byTooltip('Saved message actions'));
    await tester.pumpAndSettle();

    expect(find.text('Remove from saved'), findsOneWidget);
    expect(find.text('Remind me'), findsOneWidget);
    expect(find.text('Cancel reminder'), findsNothing);
  });

  testWidgets('a row with a reminder can change or cancel it', (tester) async {
    await pumpView(
      tester,
      items: [row(id: '1')],
      pending: [reminderFor('1', DateTime(2026, 11, 6, 15, 30))],
    );

    await tester.tap(find.byTooltip('Saved message actions'));
    await tester.pumpAndSettle();

    expect(find.text('Change reminder'), findsOneWidget);
    expect(find.text('Cancel reminder'), findsOneWidget);
  });
}
