import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

class MockSavedRepository extends Mock implements SavedRepository {}

class MockReminderRepository extends Mock implements ReminderRepository {}

SavedMessage item({
  required String id,
  String channelId = 'c1',
  String threadId = 't1',
  String? messageId,
  DateTime? savedAt,
}) => SavedMessage(
  id: id,
  target: SavedTarget(
    channelId: channelId,
    threadId: threadId,
    messageId: messageId,
  ),
  kind: messageId == null ? SavedMessageKind.thread : SavedMessageKind.reply,
  authorName: 'Ada',
  content: 'hello',
  savedAt: savedAt ?? DateTime.utc(2026, 11, 6, 8),
);

MessageReminder reminder({
  String id = 'rem-1',
  String channelId = 'c1',
  String threadId = 't1',
  String? messageId,
  DateTime? remindAt,
}) => MessageReminder(
  id: id,
  channelId: channelId,
  threadId: threadId,
  messageId: messageId,
  remindAt: remindAt ?? DateTime(2026, 11, 6, 15),
);

void main() {
  late MockSavedRepository saved;
  late MockReminderRepository reminders;

  setUpAll(() {
    registerFallbackValue(const SavedTarget(channelId: 'c', threadId: 't'));
    registerFallbackValue(ReminderPreset.inOneHour);
  });

  setUp(() {
    saved = MockSavedRepository();
    reminders = MockReminderRepository();

    when(
      () => saved.save(orgId: any(named: 'orgId'), target: any(named: 'target')),
    ).thenAnswer((_) async {});
    when(
      () => saved.remove(
        orgId: any(named: 'orgId'),
        savedMessageId: any(named: 'savedMessageId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => reminders.create(
        orgId: any(named: 'orgId'),
        target: any(named: 'target'),
        preset: any(named: 'preset'),
        tzOffsetMinutes: any(named: 'tzOffsetMinutes'),
      ),
    ).thenAnswer((_) async => reminder());
    when(
      () => reminders.delete(
        orgId: any(named: 'orgId'),
        reminderId: any(named: 'reminderId'),
      ),
    ).thenAnswer((_) async {});
  });

  ProviderContainer containerWith({
    List<SavedMessage> items = const [],
    List<MessageReminder> pending = const [],
    String org = 'org-1',
  }) {
    when(
      () => saved.list(orgId: any(named: 'orgId')),
    ).thenAnswer((_) async => items);
    when(
      () => reminders.list(orgId: any(named: 'orgId')),
    ).thenAnswer((_) async => pending);

    final container = ProviderContainer(
      overrides: [
        savedRepositoryProvider.overrideWithValue(saved),
        reminderRepositoryProvider.overrideWithValue(reminders),
        currentOrgIdProvider.overrideWithValue(org),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads saved messages and pending reminders together', () async {
    final container = containerWith(
      items: [item(id: 's1')],
      pending: [reminder()],
    );

    await container.read(savedProvider.notifier).refresh();

    final state = container.read(savedProvider);
    expect(state.items, hasLength(1));
    // The reminder is matched to its row by channel and message.
    expect(
      state.reminderFor(const SavedTarget(channelId: 'c1', threadId: 't1')),
      isNotNull,
    );
  });

  test('reading it does not fetch, so a message menu costs nothing', () async {
    final container = containerWith(items: [item(id: 's1')]);

    expect(container.read(savedProvider).items, isEmpty);
    expect(container.read(savedKeysProvider), isEmpty);
    verifyNever(() => saved.list(orgId: any(named: 'orgId')));
    verifyNever(() => reminders.list(orgId: any(named: 'orgId')));
  });

  test('with no workspace selected it asks the server for nothing', () async {
    final container = containerWith(items: [item(id: 's1')], org: '');

    await container.read(savedProvider.notifier).refresh();

    expect(container.read(savedProvider).items, isEmpty);
    verifyNever(() => saved.list(orgId: any(named: 'orgId')));
  });

  test('a failed load is reported, not shown as an empty list', () async {
    final container = containerWith();
    when(
      () => saved.list(orgId: any(named: 'orgId')),
    ).thenThrow(Exception('offline'));

    await container.read(savedProvider.notifier).refresh();

    final state = container.read(savedProvider);
    expect(state.error, isNotNull);
    expect(state.items, isEmpty);
  });

  test('rows whose reminder has passed come first, then newest saved', () {
    final due = item(id: 'due', threadId: 'due', savedAt: DateTime.utc(2026, 10));
    final recent = item(id: 'new', threadId: 'new', savedAt: DateTime.utc(2026, 11, 5));
    final old = item(id: 'old', threadId: 'old', savedAt: DateTime.utc(2026, 11));

    final sorted = SavedNotifier.sortForDisplay(
      [old, due, recent],
      {
        'c1:due': reminder(
          threadId: 'due',
          remindAt: DateTime(2026, 11, 6, 9),
        ),
      },
      now: DateTime(2026, 11, 6, 10),
    );

    expect(sorted.map((e) => e.id), ['due', 'new', 'old']);
  });

  test(
    'setting a reminder on an unsaved message saves it first, then reminds',
    () async {
      final container = containerWith();
      await container.read(savedProvider.notifier).refresh();

      const target = SavedTarget(channelId: 'c9', threadId: 't9');
      await container
          .read(savedProvider.notifier)
          .setReminder(target: target, preset: ReminderPreset.inOneHour);

      // The ticket asks for the message to be saved so the reminder has a row
      // in the Saved list; the reminder itself is a separate resource.
      verifyInOrder([
        () => saved.save(orgId: 'org-1', target: target),
        () => reminders.create(
          orgId: 'org-1',
          target: target,
          preset: ReminderPreset.inOneHour,
          tzOffsetMinutes: any(named: 'tzOffsetMinutes'),
        ),
      ]);
    },
  );

  test('a message already saved is not saved a second time', () async {
    final container = containerWith(items: [item(id: 's1')]);
    await container.read(savedProvider.notifier).refresh();

    await container.read(savedProvider.notifier).setReminder(
      target: const SavedTarget(channelId: 'c1', threadId: 't1'),
      preset: ReminderPreset.inThirtyMinutes,
    );

    verifyNever(
      () => saved.save(orgId: any(named: 'orgId'), target: any(named: 'target')),
    );
    verify(
      () => reminders.create(
        orgId: 'org-1',
        target: any(named: 'target'),
        preset: ReminderPreset.inThirtyMinutes,
        tzOffsetMinutes: any(named: 'tzOffsetMinutes'),
      ),
    ).called(1);
  });

  test('changing the time replaces the reminder rather than adding one', () async {
    final container = containerWith(
      items: [item(id: 's1')],
      pending: [reminder(id: 'rem-old')],
    );
    await container.read(savedProvider.notifier).refresh();

    await container.read(savedProvider.notifier).setReminder(
      target: const SavedTarget(channelId: 'c1', threadId: 't1'),
      preset: ReminderPreset.tomorrowMorning,
    );

    // Otherwise the message would be reminded about twice.
    verifyInOrder([
      () => reminders.delete(orgId: 'org-1', reminderId: 'rem-old'),
      () => reminders.create(
        orgId: 'org-1',
        target: any(named: 'target'),
        preset: ReminderPreset.tomorrowMorning,
        tzOffsetMinutes: any(named: 'tzOffsetMinutes'),
      ),
    ]);
  });

  test('the client sends its own UTC offset, which the server needs', () async {
    final container = containerWith();
    await container.read(savedProvider.notifier).refresh();

    await container.read(savedProvider.notifier).setReminder(
      target: const SavedTarget(channelId: 'c9', threadId: 't9'),
      preset: ReminderPreset.tomorrowMorning,
    );

    final offset =
        verify(
              () => reminders.create(
                orgId: any(named: 'orgId'),
                target: any(named: 'target'),
                preset: any(named: 'preset'),
                tzOffsetMinutes: captureAny(named: 'tzOffsetMinutes'),
              ),
            ).captured.single
            as int;
    expect(offset, DateTime.now().timeZoneOffset.inMinutes);
  });

  test('cancelling a reminder leaves the message saved', () async {
    final container = containerWith(
      items: [item(id: 's1')],
      pending: [reminder(id: 'rem-9')],
    );
    await container.read(savedProvider.notifier).refresh();

    await container
        .read(savedProvider.notifier)
        .clearReminder(const SavedTarget(channelId: 'c1', threadId: 't1'));

    verify(() => reminders.delete(orgId: 'org-1', reminderId: 'rem-9')).called(1);
    verifyNever(
      () => saved.remove(
        orgId: any(named: 'orgId'),
        savedMessageId: any(named: 'savedMessageId'),
      ),
    );
  });

  test('removing a message deletes by the saved id, not the thread id', () async {
    final container = containerWith(items: [item(id: 'saved-55')]);
    await container.read(savedProvider.notifier).refresh();

    await container
        .read(savedProvider.notifier)
        .removeTarget(const SavedTarget(channelId: 'c1', threadId: 't1'));

    verify(
      () => saved.remove(orgId: 'org-1', savedMessageId: 'saved-55'),
    ).called(1);
  });

  test('removing a message the list does not know does nothing', () async {
    final container = containerWith(items: [item(id: 'saved-55')]);
    await container.read(savedProvider.notifier).refresh();

    await container
        .read(savedProvider.notifier)
        .removeTarget(const SavedTarget(channelId: 'zz', threadId: 'zz'));

    verifyNever(
      () => saved.remove(
        orgId: any(named: 'orgId'),
        savedMessageId: any(named: 'savedMessageId'),
      ),
    );
  });

  test('a failed reminder reaches the caller instead of looking set', () async {
    final container = containerWith();
    await container.read(savedProvider.notifier).refresh();

    when(
      () => reminders.create(
        orgId: any(named: 'orgId'),
        target: any(named: 'target'),
        preset: any(named: 'preset'),
        tzOffsetMinutes: any(named: 'tzOffsetMinutes'),
      ),
    ).thenThrow(Exception('rejected'));

    await expectLater(
      container.read(savedProvider.notifier).setReminder(
        target: const SavedTarget(channelId: 'c9', threadId: 't9'),
        preset: ReminderPreset.inOneHour,
      ),
      throwsException,
    );
  });

  test('savedKeys reports which messages are saved', () async {
    final container = containerWith(items: [item(id: 's1')]);
    await container.read(savedProvider.notifier).refresh();

    final keys = container.read(savedKeysProvider);
    expect(keys.contains('c1:t1'), isTrue);
    expect(keys.contains('c1:other'), isFalse);
  });
}
