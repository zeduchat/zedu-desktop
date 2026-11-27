import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

Channel _channel(
  String name, {
  bool archived = false,
  bool hasAccess = true,
  String org = 'org-1',
}) => Channel(
  id: 'channel-$name',
  name: name,
  description: '',
  organisationId: org,
  ownerId: 'user-1',
  archived: archived,
  hasAccess: hasAccess,
);

class FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('general'),
    _channel('random'),
    _channel('old', archived: true),
    _channel('left-channel', hasAccess: false),
  ];
}

/// Holds one selected workspace, and can switch to another.
class FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );

  void switchTo(String id) {
    state = WorkspaceState(
      selectedWorkspace: Workspace(id: id, name: 'Workspace $id', avatar: ''),
    );
  }
}

/// Lists workspace A's channels until [switched] is set. After that, the next
/// build loads workspace B's channels, or fails when [failB] is set. It does
/// not watch the workspace, so it stays stale until it is invalidated, like
/// the real provider in the moment after a switch.
class SwitchingChannelNotifier extends ChannelNotifier {
  static bool switched = false;
  static bool failB = false;

  @override
  Future<List<Channel>> build() async {
    if (!switched) return [_channel('a-only')];
    if (failB) throw const ApiFailure(message: 'Could not load channels');
    return [_channel('b-only', org: 'org-2')];
  }
}

class _MockChannelRepository extends Mock implements ChannelRepository {}

void main() {
  group('SidebarChannelList unread badges', () {
    late ProviderContainer container;

    // The real ChannelNotifier, so opening a channel clears its count the
    // way it does in the app.
    Future<void> pumpUnread(WidgetTester tester) async {
      final repository = _MockChannelRepository();
      when(() => repository.fetchChannels(any())).thenAnswer(
        (_) async => Success<List<Channel>>([
          _channel('general').copyWith(unreadCount: 4),
          _channel('random').copyWith(unreadCount: 3),
          _channel('busy').copyWith(unreadCount: 150),
          _channel('quiet'),
        ]),
      );
      container = ProviderContainer(
        overrides: [
          channelRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(
            const Scaffold(body: SidebarChannelList()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder badgeOf(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)),
      matching: find.byKey(const Key('sidebar-channel-unread-badge')),
    );

    testWidgets('shows the count on channels with unread messages only', (
      tester,
    ) async {
      await pumpUnread(tester);

      expect(find.text('3'), findsOneWidget);
      expect(badgeOf('random'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      expect(badgeOf('quiet'), findsNothing);
      // general is open on start, so it has been read.
      expect(badgeOf('general'), findsNothing);
      expect(find.text('4'), findsNothing);
      expect(
        tester.widget<Text>(find.text('random')).style?.fontWeight,
        FontWeight.w600,
      );
      expect(tester.widget<Text>(find.text('quiet')).style?.fontWeight, isNull);
    });

    testWidgets('opening a channel clears its badge for good', (tester) async {
      await pumpUnread(tester);
      expect(badgeOf('random'), findsOneWidget);

      await tester.tap(find.text('random'));
      await tester.pumpAndSettle();
      expect(badgeOf('random'), findsNothing);

      await tester.tap(find.text('quiet'));
      await tester.pumpAndSettle();
      expect(badgeOf('random'), findsNothing);
      expect(
        container
            .read(channelProvider)
            .value!
            .firstWhere((c) => c.name == 'random')
            .unreadCount,
        0,
      );
      expect(badgeOf('busy'), findsOneWidget);
    });
  });

  group('SidebarChannelList', () {
    late ProviderContainer container;

    Future<void> pumpList(
      WidgetTester tester, {
      required ChannelNotifier Function() channels,
    }) async {
      container = ProviderContainer(
        overrides: [
          channelProvider.overrideWith(channels),
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(
            const Scaffold(body: SidebarChannelList()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    FakeWorkspaceNotifier workspace() =>
        container.read(workspaceProvider.notifier) as FakeWorkspaceNotifier;

    testWidgets('lists the active channels and hides archived ones', (
      tester,
    ) async {
      await pumpList(tester, channels: FakeChannelNotifier.new);

      expect(find.text('general'), findsOneWidget);
      expect(find.text('random'), findsOneWidget);
      expect(find.text('old'), findsNothing);
      expect(find.text('left-channel'), findsNothing);
    });

    group('after a workspace switch', () {
      setUp(() {
        SwitchingChannelNotifier.switched = false;
        SwitchingChannelNotifier.failB = false;
      });

      testWidgets('hides the old channels until the new ones arrive', (
        tester,
      ) async {
        await pumpList(tester, channels: SwitchingChannelNotifier.new);
        expect(find.text('a-only'), findsOneWidget);

        // The workspace changes before the channel list has reloaded.
        workspace().switchTo('org-2');
        await tester.pumpAndSettle();
        expect(find.text('a-only'), findsNothing);

        SwitchingChannelNotifier.switched = true;
        container.invalidate(channelProvider);
        await tester.pumpAndSettle();

        expect(find.text('b-only'), findsOneWidget);
        expect(find.text('a-only'), findsNothing);
      });

      testWidgets('shows no channels when the new load fails', (tester) async {
        await pumpList(tester, channels: SwitchingChannelNotifier.new);
        expect(find.text('a-only'), findsOneWidget);

        workspace().switchTo('org-2');
        SwitchingChannelNotifier.switched = true;
        SwitchingChannelNotifier.failB = true;
        container.invalidate(channelProvider);
        await tester.pumpAndSettle();

        expect(find.text('a-only'), findsNothing);
        expect(find.text('b-only'), findsNothing);
      });
    });

    group('highlights the open channel', () {
      bool isHighlighted(WidgetTester tester, String name) {
        final ink = tester.widget<Ink>(
          find.ancestor(of: find.text(name), matching: find.byType(Ink)),
        );
        return (ink.decoration! as BoxDecoration).color != Colors.transparent;
      }

      testWidgets('and moves it when another channel opens', (tester) async {
        await pumpList(tester, channels: FakeChannelNotifier.new);
        expect(isHighlighted(tester, 'general'), isTrue);
        expect(isHighlighted(tester, 'random'), isFalse);

        await tester.tap(find.text('random'));
        await tester.pump();

        expect(isHighlighted(tester, 'general'), isFalse);
        expect(isHighlighted(tester, 'random'), isTrue);
      });

      testWidgets('but not a channel named like the open group DM', (
        tester,
      ) async {
        await pumpList(tester, channels: FakeChannelNotifier.new);

        container.read(activeChatProvider.notifier).selectGroupDm('random');
        await tester.pump();

        expect(isHighlighted(tester, 'general'), isFalse);
        expect(isHighlighted(tester, 'random'), isFalse);
      });

      testWidgets(
        'renders accent indicator bar and distinct hash mark on active channel',
        (tester) async {
          await pumpList(tester, channels: FakeChannelNotifier.new);

          // Active channel has an accent DecoratedBox indicator bar
          final generalItem = find.ancestor(
            of: find.text('general'),
            matching: find.byType(Ink),
          );
          final indicator = find.descendant(
            of: generalItem,
            matching: find.byType(DecoratedBox),
          );
          expect(indicator, findsOneWidget);

          // Inactive channel does not have an indicator bar
          final randomItem = find.ancestor(
            of: find.text('random'),
            matching: find.byType(Ink),
          );
          final randomIndicator = find.descendant(
            of: randomItem,
            matching: find.byType(DecoratedBox),
          );
          expect(randomIndicator, findsNothing);
        },
      );
    });

    testWidgets('tapping a channel opens it', (tester) async {
      await pumpList(tester, channels: FakeChannelNotifier.new);
      expect(container.read(activeChatProvider).id, 'general');

      await tester.tap(find.text('random'));
      await tester.pump();

      expect(
        container.read(activeChatProvider),
        const ActiveChatState(
          type: ActiveChatType.channel,
          id: 'random',
          channelId: 'channel-random',
        ),
      );
    });
  });
}
