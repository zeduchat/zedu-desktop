import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

Channel _channel(String name, {String? topic}) => Channel(
  id: 'channel-$name',
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'user-1',
  topic: topic,
);

class _TopicChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('general', topic: 'Release planning'),
    _channel('random'),
  ];
}

class _MemberCountChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('general').copyWith(membersCount: 12),
    _channel('random').copyWith(membersCount: 1),
  ];
}

class _EmptyChannelRepository extends Mock implements ChannelRepository {
  @override
  Future<Result<ChannelMessagePage>> fetchChannelMessages(
    String id, {
    int page = 1,
  }) async => const Success(ChannelMessagePage(messages: [], hasMore: false));

  @override
  Future<Result<List<DmParticipant>>> fetchChannelMembers(String id) async =>
      Success([
        DmParticipant(userId: 'u1', username: 'ada', email: 'ada@zedu.chat'),
      ]);
}

class _LinksChannelRepository extends _EmptyChannelRepository {
  @override
  Future<Result<ChannelMessagePage>> fetchChannelMessages(
    String id, {
    int page = 1,
  }) async => Success(
    ChannelMessagePage(
      messages: [
        ChannelMessage(
          senderName: 'Ada',
          text: 'Roadmap',
          rawContent: '<a href="https://zedu.chat/roadmap">Roadmap</a>',
          createdAt: DateTime.utc(2026, 11, 1, 9),
        ),
      ],
      hasMore: false,
    ),
  );
}

/// Records leave calls and answers with [leaveResult].
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

/// Records archive calls and answers with [archiveResult].
class _ArchivingChannelRepository extends _EmptyChannelRepository {
  _ArchivingChannelRepository(this.archiveResult);

  final Result<void> archiveResult;
  final archived = <(String, bool)>[];

  @override
  Future<Result<void>> archiveChannel(String channelId, bool value) async {
    archived.add((channelId, value));
    return archiveResult;
  }

  @override
  Future<Result<List<Channel>>> fetchArchivedChannels(String orgId) async =>
      const Success(<Channel>[]);
}

/// Keeps every export running, so the export dialog stays on "Preparing".
class _ExportingChannelRepository extends _EmptyChannelRepository {
  final exported = <String>[];

  @override
  Future<Result<ChannelExport>> startChannelExport(String channelId) async {
    exported.add(channelId);
    return const Success(
      ChannelExport(id: 'e1', status: ChannelExportStatus.pending),
    );
  }

  @override
  Future<Result<ChannelExport>> fetchChannelExportStatus(
    String channelId,
  ) async => const Success(
    ChannelExport(id: 'e1', status: ChannelExportStatus.pending),
  );
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

    testWidgets('shows the channel topic in the header when set (#2852)', (
      tester,
    ) async {
      await pumpSidebarAndChat(tester, channels: _TopicChannelNotifier.new);

      expect(find.text('Release planning'), findsOneWidget);

      await tester.tap(find.text('random'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('channel_header_topic')), findsNothing);
    });

    testWidgets('shows the channel member count in the header (#3062)', (
      tester,
    ) async {
      await pumpSidebarAndChat(
        tester,
        channels: _MemberCountChannelNotifier.new,
      );

      expect(
        find.byKey(const ValueKey('channel_header_member_count')),
        findsOneWidget,
      );
      expect(find.text('12 members'), findsOneWidget);

      await tester.tap(find.text('random'));
      await tester.pumpAndSettle();

      expect(find.text('1 member'), findsOneWidget);
      expect(find.text('12 members'), findsNothing);
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

    testWidgets('starts on the shared generalChannelName channel (#3779)', (
      tester,
    ) async {
      await pumpSidebarAndChat(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeChatArea)),
      );
      expect(container.read(activeChatProvider).id, generalChannelName);
      expect(find.text('# $generalChannelName'), findsOneWidget);
    });

    for (final name in ['', '   ']) {
      testWidgets(
        'a channel pick with no name says so, not #general (#3779, "$name")',
        (tester) async {
          await pumpSidebarAndChat(tester);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(HomeChatArea)),
          );

          container.read(activeChatProvider.notifier).selectChannel(name);
          await tester.pumpAndSettle();

          expect(find.text('Pick a channel from the sidebar.'), findsOneWidget);
          expect(find.text('# general'), findsNothing);
          expect(find.text('Welcome to #general'), findsNothing);

          // Picking a real channel afterwards opens it as usual.
          await tester.tap(find.text('random'));
          await tester.pumpAndSettle();
          expect(find.text('# random'), findsOneWidget);
          expect(find.text('Pick a channel from the sidebar.'), findsNothing);
        },
      );
    }

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

    testWidgets('the channel menu opens links shared in that channel', (
      tester,
    ) async {
      await pumpSidebarAndChat(tester, repository: _LinksChannelRepository());

      await tester.tap(find.byKey(const ValueKey('channel-header-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View links'));
      await tester.pumpAndSettle();

      expect(find.text('#general links'), findsOneWidget);
      expect(find.text('https://zedu.chat/roadmap'), findsOneWidget);
      expect(find.textContaining('Ada ·'), findsOneWidget);
    });

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
        const Failure(
          ApiFailure(
            message: 'You cannot leave this channel',
            kind: ApiFailureKind.client,
          ),
        ),
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

    for (final (kind, expected) in [
      (
        ApiFailureKind.network,
        'No internet connection. Check your network and try again.',
      ),
      (
        ApiFailureKind.server,
        'Something went wrong on our end. Please try again later.',
      ),
      (ApiFailureKind.unknown, 'Could not leave #random. Please try again.'),
      (ApiFailureKind.parsing, 'Could not leave #random. Please try again.'),
    ]) {
      testWidgets('leave failure $kind shows safe copy and keeps the channel', (
        tester,
      ) async {
        final repository = _LeavingChannelRepository(
          Failure(
            ApiFailure(
              message: '<html>internal-host failure</html>',
              kind: kind,
            ),
          ),
        );
        await pumpSidebarAndChat(tester, repository: repository);
        await leaveRandom(tester);
        await tester.tap(find.widgetWithText(TextButton, 'Leave'));
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        expect(find.textContaining('internal-host'), findsNothing);
        expect(find.text('# random'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      });
    }

    Future<void> archiveRandom(WidgetTester tester) async {
      await tester.tap(find.text('random'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('channel-header-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive channel'));
      await tester.pumpAndSettle();
    }

    testWidgets('archiving a channel removes it and opens another one', (
      tester,
    ) async {
      final repository = _ArchivingChannelRepository(const Success(null));
      await pumpSidebarAndChat(tester, repository: repository);

      await archiveRandom(tester);
      expect(find.text('Archive #random?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(repository.archived, [('channel-random', true)]);
      expect(find.text('random'), findsNothing);
      expect(find.text('# general'), findsOneWidget);
      expect(find.text('#random was archived'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('cancelling the archive dialog keeps the channel', (
      tester,
    ) async {
      final repository = _ArchivingChannelRepository(const Success(null));
      await pumpSidebarAndChat(tester, repository: repository);

      await archiveRandom(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.archived, isEmpty);
      expect(find.text('# random'), findsOneWidget);
    });

    testWidgets(
      'a forbidden archive says who can do it and keeps the channel',
      (tester) async {
        final repository = _ArchivingChannelRepository(
          const Failure(
            ApiFailure(
              message: 'unauthorized, only channel owner or channel manager',
              kind: ApiFailureKind.forbidden,
            ),
          ),
        );
        await pumpSidebarAndChat(tester, repository: repository);

        await archiveRandom(tester);
        await tester.tap(find.widgetWithText(TextButton, 'Archive'));
        await tester.pumpAndSettle();

        expect(
          find.text('Only the channel owner or an admin can archive #random.'),
          findsOneWidget,
        );
        expect(find.text('# random'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('the header menu exports the channel history (Ziki #2629)', (
      tester,
    ) async {
      final repository = _ExportingChannelRepository();
      await pumpSidebarAndChat(tester, repository: repository);
      await tester.tap(find.text('random'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('channel-header-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export history'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Export #random'), findsOneWidget);
      expect(repository.exported, ['channel-random']);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    group('search in a channel (Ziki #2849)', () {
      Future<void> openSearch(WidgetTester tester) async {
        await tester.tap(find.byKey(const ValueKey('channel-header-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Search in channel'));
        await tester.pumpAndSettle();
      }

      testWidgets('opens the full-history search for this channel', (
        tester,
      ) async {
        await pumpSidebarAndChat(tester);
        expect(find.byType(SearchPanel), findsNothing);

        await openSearch(tester);

        final panel = tester.widget<SearchPanel>(find.byType(SearchPanel));
        expect(panel.channelId, 'channel-general');
        expect(find.text('# general'), findsOneWidget);
      });

      testWidgets('Close search hides it again', (tester) async {
        await pumpSidebarAndChat(tester);
        await openSearch(tester);

        await tester.tap(find.byTooltip('Close search'));
        await tester.pumpAndSettle();

        expect(find.byType(SearchPanel), findsNothing);
      });

      testWidgets('another channel opens without the search', (tester) async {
        await pumpSidebarAndChat(tester);
        await openSearch(tester);

        await tester.tap(find.text('random'));
        await tester.pumpAndSettle();

        expect(find.text('# random'), findsOneWidget);
        expect(find.byType(SearchPanel), findsNothing);
      });
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

    testWidgets(
      'reclamps width when minWidth or maxWidth changes in didUpdateWidget',
      (tester) async {
        await tester.pumpWidget(
          buildTestMaterialApp(
            const Scaffold(
              body: ResizableSidebar(
                initialWidth: 350,
                minWidth: 200,
                maxWidth: 400,
                child: Text('Sidebar'),
              ),
            ),
          ),
        );

        final resizableSidebar = find.byKey(
          const ValueKey('resizable-sidebar'),
        );
        expect(tester.getSize(resizableSidebar).width, 350);

        // Update widget with lower maxWidth: 300
        await tester.pumpWidget(
          buildTestMaterialApp(
            const Scaffold(
              body: ResizableSidebar(
                initialWidth: 350,
                minWidth: 200,
                maxWidth: 300,
                child: Text('Sidebar'),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.getSize(resizableSidebar).width, 300);

        // Update widget with higher minWidth: 320
        await tester.pumpWidget(
          buildTestMaterialApp(
            const Scaffold(
              body: ResizableSidebar(
                initialWidth: 350,
                minWidth: 320,
                maxWidth: 400,
                child: Text('Sidebar'),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.getSize(resizableSidebar).width, 320);
      },
    );
  });
}
