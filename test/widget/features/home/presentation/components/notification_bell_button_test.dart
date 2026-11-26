import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _Dms extends DmListNotifier {
  _Dms(this.conversations);

  final List<DmConversation> conversations;

  @override
  Future<List<DmConversation>> build() async => conversations;
}

DmConversation _dm(
  String id,
  String name, {
  int unread = 0,
  DateTime? lastReadAt,
}) => DmConversation(
  channelId: id,
  username: name,
  participantId: 'p-$id',
  previewMessage: 'Hello from $name',
  unreadCount: unread,
  lastReadAt: lastReadAt,
);

const _delay = Duration(milliseconds: 180);
final _popover = find.byKey(const Key('notification-preview-popover'));

void main() {
  late ProviderContainer container;

  Future<TestGesture> pumpBell(
    WidgetTester tester, {
    List<DmConversation> dms = const [],
  }) async {
    container = ProviderContainer(
      overrides: [
        currentOrgIdProvider.overrideWithValue('org-test'),
        dmListProvider.overrideWith(() => _Dms(dms)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestMaterialApp(
          const Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: NotificationBellButton(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(400, 50));
    addTearDown(gesture.removePointer);
    return gesture;
  }

  Future<void> hoverBell(WidgetTester tester, TestGesture gesture) async {
    await gesture.moveTo(
      tester.getCenter(find.byIcon(Icons.notifications_none_outlined)),
    );
    await tester.pump(_delay);
    await tester.pump();
  }

  testWidgets('hovering the bell previews the 3 most recent unread DMs', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 26, 12);
    final gesture = await pumpBell(
      tester,
      dms: [
        _dm('c-1', 'Oldest', unread: 1, lastReadAt: now),
        _dm('c-2', 'Read', lastReadAt: now.add(const Duration(hours: 5))),
        _dm('c-3', 'Newest', unread: 2, lastReadAt: now.add(_hours(4))),
        _dm('c-4', 'Second', unread: 1, lastReadAt: now.add(_hours(3))),
        _dm('c-5', 'Third', unread: 4, lastReadAt: now.add(_hours(2))),
      ],
    );

    await gesture.moveTo(
      tester.getCenter(find.byIcon(Icons.notifications_none_outlined)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(_popover, findsNothing, reason: 'waits for the hover delay');

    await tester.pump(_delay);
    await tester.pump();

    expect(_popover, findsOneWidget);
    final names = tester
        .widgetList<UnreadDmRow>(find.byType(UnreadDmRow))
        .map((row) => row.conversation.displayName)
        .toList();
    expect(names, ['Newest', 'Second', 'Third']);
    expect(find.text('Oldest'), findsNothing);
    expect(find.text('Read'), findsNothing);
    expect(find.text('View all notifications'), findsOneWidget);
  });

  testWidgets('shows the caught-up state when nothing is unread', (
    tester,
  ) async {
    final gesture = await pumpBell(tester, dms: [_dm('c-1', 'Ada')]);
    await hoverBell(tester, gesture);

    expect(_popover, findsOneWidget);
    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.byType(UnreadDmRow), findsNothing);
  });

  testWidgets('stays open over the popover and closes after leaving it', (
    tester,
  ) async {
    final gesture = await pumpBell(tester, dms: [_dm('c-1', 'Ada', unread: 1)]);
    await hoverBell(tester, gesture);

    await gesture.moveTo(tester.getCenter(find.text('Ada')));
    await tester.pump(_delay * 2);
    expect(_popover, findsOneWidget);

    await gesture.moveTo(const Offset(790, 10));
    await tester.pump(_delay);
    await tester.pump();
    expect(_popover, findsNothing);
  });

  testWidgets('Escape closes the preview', (tester) async {
    final gesture = await pumpBell(tester, dms: [_dm('c-1', 'Ada', unread: 1)]);
    await hoverBell(tester, gesture);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(_popover, findsNothing);
  });

  testWidgets('clicking a previewed DM opens it and closes the preview', (
    tester,
  ) async {
    final ada = _dm('c-1', 'Ada', unread: 1);
    final gesture = await pumpBell(tester, dms: [ada]);
    await hoverBell(tester, gesture);

    await tester.tap(find.text('Ada'));
    await tester.pump();

    expect(_popover, findsNothing);
    expect(container.read(selectedDmProvider)?.channelId, 'c-1');
    expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
  });

  testWidgets('View all and clicking the bell open the notifications panel', (
    tester,
  ) async {
    final gesture = await pumpBell(tester, dms: [_dm('c-1', 'Ada', unread: 1)]);
    await hoverBell(tester, gesture);

    await tester.tap(find.text('View all notifications'));
    await tester.pumpAndSettle();
    expect(_popover, findsNothing);
    expect(find.byType(NotificationsDialog), findsOneWidget);

    Navigator.of(tester.element(find.byType(NotificationsDialog))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsDialog), findsNothing);

    await tester.tap(find.byIcon(Icons.notifications_none_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsDialog), findsOneWidget);
  });
}

Duration _hours(int hours) => Duration(hours: hours);
