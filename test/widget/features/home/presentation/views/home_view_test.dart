import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

Channel _channel(String name) => Channel(
  id: 'channel-$name',
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'user-1',
);

class _EmptyChannelRepository extends Mock implements ChannelRepository {
  @override
  Future<Result<List<ChannelMessage>>> fetchChannelMessages(String id) async =>
      const Success(<ChannelMessage>[]);

  @override
  Future<Result<List<DmParticipant>>> fetchChannelMembers(String id) async =>
      Success([
        DmParticipant(userId: 'u1', username: 'ada', email: 'ada@zedu.chat'),
      ]);
}

/// Records leave calls and answers with [leaveResult].
class _FakeNotificationService extends Fake
    implements ChannelNotificationService {
  @override
  Future<ChannelNotificationPreference> load(String channelId) async =>
      const ChannelNotificationPreference();
}

class _LeavingChannelRepository extends _EmptyChannelRepository {
  _LeavingChannelRepository(this.leaveResult);

  final Result<void> leaveResult;
  final left = <String>[];

  @override
  Future<Result<void>> leaveChannel(String channelId) async {
    left.add(channelId);
    return leaveResult;
  }
}

class FakeSecureStorageService extends Fake implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> readData(String key) async => _values[key];

  @override
  Future<void> writeData(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);
}

class _FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('general'),
    _channel('random'),
  ];
}

class _CaseChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('general'),
    _channel('engineering'),
    _channel('Engineering'),
  ];
}

final _longName = List.filled(61, 'a').join();

class _LongNameChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [_channel(_longName)];
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
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

void main() {
  group('HomeChatArea', () {
    Future<void> pumpSidebarAndChat(
      WidgetTester tester, {
      ChannelNotifier Function() channels = _FakeChannelNotifier.new,
      double width = 1600,
      ChannelRepository? repository,
      ChannelNotificationService? notificationService,
    }) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelProvider.overrideWith(channels),
            workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
            channelRepositoryProvider.overrideWithValue(
              repository ?? _EmptyChannelRepository(),
            ),
            if (notificationService != null)
              channelNotificationServiceProvider.overrideWithValue(
                notificationService,
              ),
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(
                FakeSecureStorageService(),
                userId: 'user-1',
                orgId: 'org-1',
              ),
            ),
          ],
          child: buildTestMaterialApp(
            const Scaffold(
              body: Row(
                children: [
                  SizedBox(width: 320, child: SidebarChannelList()),
                  Expanded(child: HomeChatArea()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows #general until another channel is picked', (
      tester,
    ) async {
      await pumpSidebarAndChat(tester);

      expect(find.text('# general'), findsOneWidget);
      expect(find.text('Welcome to #general'), findsOneWidget);
    });

    testWidgets('clicking a sidebar channel opens it in the chat area', (
      tester,
    ) async {
      await pumpSidebarAndChat(tester);

      await tester.tap(find.text('random'));
      await tester.pumpAndSettle();

      expect(find.text('# random'), findsOneWidget);
      expect(find.text('Welcome to #random'), findsOneWidget);
      expect(find.text('# general'), findsNothing);
    });

    testWidgets(
      'channels whose names differ only by case open their own channel',
      (tester) async {
        await pumpSidebarAndChat(tester, channels: _CaseChannelNotifier.new);

        String composerChannelId() => tester
            .widget<DmMessageComposer>(find.byType(DmMessageComposer))
            .channelId;

        await tester.tap(find.text('Engineering'));
        await tester.pumpAndSettle();
        expect(find.text('# Engineering'), findsOneWidget);
        expect(composerChannelId(), 'channel-Engineering');

        await tester.tap(find.text('engineering'));
        await tester.pumpAndSettle();
        expect(find.text('# engineering'), findsOneWidget);
        expect(composerChannelId(), 'channel-engineering');
      },
    );

    testWidgets('goes back to #general when the workspace changes', (
      tester,
    ) async {
      await pumpSidebarAndChat(tester);
      await tester.tap(find.text('random'));
      await tester.pumpAndSettle();
      expect(find.text('# random'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeChatArea)),
      );
      (container.read(workspaceProvider.notifier) as _FakeWorkspaceNotifier)
          .switchTo('org-2');
      await tester.pumpAndSettle();

      expect(find.text('# general'), findsOneWidget);
      expect(find.text('# random'), findsNothing);
    });

    testWidgets('the channel composer gets the channel members to mention', (
      tester,
    ) async {
      await pumpSidebarAndChat(tester);

      final composer = tester.widget<DmMessageComposer>(
        find.byType(DmMessageComposer),
      );
      expect(composer.isChannel, isTrue);
      expect(composer.participants.map((p) => p.username), ['ada']);
    });

    testWidgets('a very long channel name does not overflow', (tester) async {
      await pumpSidebarAndChat(
        tester,
        channels: _LongNameChannelNotifier.new,
        width: 1000,
      );

      await tester.tap(find.text(_longName));
      await tester.pumpAndSettle();

      // The name shows in the sidebar row and in the chat header.
      expect(find.text('# $_longName'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    Future<void> leaveRandom(WidgetTester tester) async {
      await tester.tap(find.text('random'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('channel-header-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave channel'));
      await tester.pumpAndSettle();
    }

    testWidgets('leaving a channel removes it and opens another one', (
      tester,
    ) async {
      final repository = _LeavingChannelRepository(const Success(null));
      await pumpSidebarAndChat(tester, repository: repository);

      await leaveRandom(tester);
      expect(find.text('Leave #random?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(repository.left, ['channel-random']);
      expect(find.text('random'), findsNothing);
      expect(find.text('# general'), findsOneWidget);
      expect(find.text('You left #random'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets(
      'the channel menu opens that channel\'s notification settings',
      (tester) async {
        await pumpSidebarAndChat(
          tester,
          notificationService: _FakeNotificationService(),
        );

        await tester.tap(find.text('random'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('channel-header-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Notification settings'));
        await tester.pumpAndSettle();

        expect(find.text('Notifications for #random'), findsOneWidget);
        expect(find.text('Mentions'), findsOneWidget);
      },
    );

    testWidgets('cancelling the dialog keeps the channel', (tester) async {
      final repository = _LeavingChannelRepository(const Success(null));
      await pumpSidebarAndChat(tester, repository: repository);

      await leaveRandom(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.left, isEmpty);
      expect(find.text('# random'), findsOneWidget);
    });

    testWidgets('a failed leave shows the error and keeps the channel', (
      tester,
    ) async {
      final repository = _LeavingChannelRepository(
        const Failure(ApiFailure(message: 'You cannot leave this channel')),
      );
      await pumpSidebarAndChat(tester, repository: repository);

      await leaveRandom(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(repository.left, ['channel-random']);
      expect(find.text('You cannot leave this channel'), findsOneWidget);
      expect(find.text('# random'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('ResizableSidebar', () {
    testWidgets(
      'respects the minimum and maximum width limits while dragging',
      (tester) async {
        await tester.pumpWidget(
          buildTestMaterialApp(
            Scaffold(
              body: ResizableSidebar(
                child: Container(
                  color: Colors.blue,
                  child: const Center(child: Text('Sidebar content')),
                ),
              ),
            ),
          ),
        );

        final resizableSidebar = find.byKey(
          const ValueKey('resizable-sidebar'),
        );
        final resizeHandle = find.byKey(
          const ValueKey('resizable-sidebar-handle'),
        );

        expect(tester.getSize(resizableSidebar).width, 320);

        final handleCenter = tester.getCenter(resizeHandle);
        final drag = await tester.startGesture(handleCenter);
        await drag.moveBy(const Offset(-1000, 0));
        await tester.pump();

        expect(
          tester.getSize(resizableSidebar).width,
          greaterThanOrEqualTo(ResizableSidebar.defaultMinWidth),
        );
        expect(
          tester.getSize(resizableSidebar).width,
          lessThanOrEqualTo(ResizableSidebar.defaultMaxWidth),
        );

        await drag.moveBy(const Offset(1000, 0));
        await tester.pump();

        expect(
          tester.getSize(resizableSidebar).width,
          lessThanOrEqualTo(ResizableSidebar.defaultMaxWidth),
        );
        expect(
          tester.getSize(resizableSidebar).width,
          greaterThanOrEqualTo(ResizableSidebar.defaultMinWidth),
        );
      },
    );
  });
}
