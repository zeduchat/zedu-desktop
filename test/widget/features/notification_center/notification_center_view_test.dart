import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

/// Serves fixed notifications and records what the page asks for.
class _FakeNotificationCenter extends NotificationCenterNotifier {
  _FakeNotificationCenter(this.initial);

  final NotificationCenterState initial;
  final selected = <String>[];

  @override
  NotificationCenterState build() => initial;

  @override
  Future<void> refresh() async {}

  int loadMoreCalls = 0;

  @override
  Future<void> loadMore() async => loadMoreCalls++;

  @override
  Future<void> select(AppNotification item) async {
    selected.add(item.id);
    state = state.copyWith(
      selectedId: item.id,
      readIds: {...state.readIds, item.id},
    );
  }
}

final _dm = AppNotification(
  id: 'dm1',
  title: 'Jemi',
  message: 'Estimate done',
  sentAt: DateTime(2026, 11, 26, 17, 31),
  notificationType: 'dm',
  channelId: 'c1',
  participantId: 'u2',
);

final _mention = AppNotification(
  id: 'm1',
  title: '#saviour',
  message: 'need you to help estimate this too',
  sentAt: DateTime(2026, 11, 26, 17, 12),
  notificationType: 'mention',
  channelId: 'ch9',
  channelName: 'saviour',
  serverRead: true,
);

Future<_FakeNotificationCenter> _pump(
  WidgetTester tester,
  NotificationCenterState state, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final fake = _FakeNotificationCenter(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notificationCenterProvider.overrideWith(() => fake)],
      child: buildTestMaterialApp(
        const Scaffold(body: NotificationCenterBody()),
      ),
    ),
  );
  await tester.pump();
  return fake;
}

void main() {
  group('Notifications page (Ziki #33700)', () {
    testWidgets('lists DMs and mentions with times, and a dot on unread', (
      tester,
    ) async {
      await _pump(tester, NotificationCenterState(items: [_dm, _mention]));

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Jemi'), findsOneWidget);
      expect(find.text('#saviour'), findsOneWidget);
      expect(find.text('Estimate done'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread_dm1')), findsOneWidget);
      expect(find.byKey(const ValueKey('unread_m1')), findsNothing);
      expect(find.text('Select a notification'), findsOneWidget);
    });

    testWidgets('selecting one shows it, marks it read and keeps it listed', (
      tester,
    ) async {
      final fake = await _pump(
        tester,
        NotificationCenterState(items: [_dm, _mention]),
      );

      await tester.tap(find.byKey(const ValueKey('notification_dm1')));
      await tester.pump();

      expect(fake.selected, ['dm1']);
      expect(find.text('Select a notification'), findsNothing);
      expect(find.text('Direct message'), findsOneWidget);
      expect(
        find.text('Reply in your direct message conversation.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notification_open_conversation')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('unread_dm1')), findsNothing);
      expect(find.byKey(const ValueKey('notification_dm1')), findsOneWidget);
    });

    testWidgets('a channel mention offers to view it in its channel', (
      tester,
    ) async {
      await _pump(
        tester,
        NotificationCenterState(items: [_mention], selectedId: 'm1'),
      );

      expect(find.text('Mention'), findsOneWidget);
      expect(find.text('View this message in its channel.'), findsOneWidget);
    });

    testWidgets('shows an empty state with no notifications', (tester) async {
      await _pump(tester, const NotificationCenterState());

      expect(find.text('No recent notifications'), findsOneWidget);
    });

    testWidgets('a narrow window shows one pane at a time without overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        NotificationCenterState(items: [_dm, _mention]),
        size: const Size(480, 800),
      );

      expect(find.text('Select a notification'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('notification_dm1')));
      await tester.pump();
      expect(find.text('Direct message'), findsOneWidget);
      expect(find.byKey(const ValueKey('notification_dm1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('notifications_back')));
      await tester.pump();
      expect(find.byKey(const ValueKey('notification_dm1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('NotificationCenterState unread rules', () {
    test('read on the server, read here, or older than first visit', () {
      final seen = DateTime(2026, 11, 26, 17, 20);
      final state = NotificationCenterState(
        items: [_dm, _mention],
        seenAt: seen,
      );

      expect(state.isUnread(_dm), isTrue); // newer than the first visit
      expect(state.isUnread(_mention), isFalse); // read on the server
      expect(state.unreadCount, 1);
      expect(state.copyWith(readIds: {'dm1'}).unreadCount, 0);
      final older = AppNotification(
        id: 'old',
        title: 'x',
        message: 'y',
        sentAt: DateTime(2026, 11, 26, 9),
      );
      expect(state.isUnread(older), isFalse);
    });
  });

  testWidgets('a failed page shows the error with a Retry (Ziki #33700)', (
    tester,
  ) async {
    final fake = await _pump(
      tester,
      NotificationCenterState(
        items: [_dm, _mention],
        hasMore: true,
        loadMoreError: 'Could not load more notifications.',
      ),
    );

    expect(
      find.byKey(const ValueKey('notifications_load_more_error')),
      findsOneWidget,
    );
    expect(find.text('Could not load more notifications.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(fake.loadMoreCalls, 1);
  });
}
