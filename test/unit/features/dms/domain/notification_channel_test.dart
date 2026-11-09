import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

Channel _channel(String id, String name) => Channel(
  id: id,
  name: name,
  description: '',
  organisationId: 'org-test',
  ownerId: 'owner',
);

void main() {
  final general = _channel('ch-general', 'general');
  final design = _channel('ch-design', 'design');

  group('channel message notifications', () {
    test('a channel message names the channel, not a DM', () {
      expect(
        notificationTitle(senderName: 'Alice', channel: general),
        'New message in #general',
      );
      expect(
        notificationBody(
          senderName: 'Alice',
          preview: 'Lunch?',
          channel: general,
        ),
        'Alice: Lunch?',
      );
    });

    test('a DM keeps its title and body', () {
      expect(notificationTitle(senderName: 'Alice'), 'New DM from Alice');
      expect(
        notificationBody(senderName: 'Alice', preview: 'Lunch?'),
        'Lunch?',
      );
    });

    test('a long channel body is still shortened to 80 characters', () {
      final body = notificationBody(
        senderName: 'Alice',
        preview: 'x' * 200,
        channel: general,
      );
      expect(body.characters.length, 80);
      expect(body.endsWith('...'), isTrue);
    });

    test('finds a channel by id and returns null for a DM', () {
      final channels = [general, design];
      expect(channelForNotification(channels, 'ch-design'), design);
      expect(channelForNotification(channels, 'dm-1'), isNull);
    });
  });

  group('isChannelOpen', () {
    test('is true for the picked channel on the Home pane', () {
      const chat = ActiveChatState(
        type: ActiveChatType.channel,
        id: 'design',
        channelId: 'ch-design',
      );
      expect(
        isChannelOpen(
          chat: chat,
          sidebar: HomeSidebarType.home,
          channel: design,
        ),
        isTrue,
      );
    });

    test('is false for another channel', () {
      const chat = ActiveChatState(
        type: ActiveChatType.channel,
        id: 'design',
        channelId: 'ch-design',
      );
      expect(
        isChannelOpen(
          chat: chat,
          sidebar: HomeSidebarType.home,
          channel: general,
        ),
        isFalse,
      );
    });

    test('is false while a DM is on screen', () {
      const chat = ActiveChatState(
        type: ActiveChatType.channel,
        id: 'design',
        channelId: 'ch-design',
      );
      expect(
        isChannelOpen(
          chat: chat,
          sidebar: HomeSidebarType.dms,
          channel: design,
        ),
        isFalse,
      );
    });

    test('is false when the open chat is not a channel', () {
      const chat = ActiveChatState(type: ActiveChatType.groupDm, id: 'design');
      expect(
        isChannelOpen(
          chat: chat,
          sidebar: HomeSidebarType.home,
          channel: design,
        ),
        isFalse,
      );
    });

    test('finds #general by name before any channel is picked', () {
      expect(
        isChannelOpen(
          chat: ActiveChatState.generalChannel,
          sidebar: HomeSidebarType.home,
          channel: general,
        ),
        isTrue,
      );
      expect(
        isChannelOpen(
          chat: ActiveChatState.generalChannel,
          sidebar: HomeSidebarType.home,
          channel: design,
        ),
        isFalse,
      );
    });
  });

  group('clicking a channel notification', () {
    testWidgets('opens that channel on Home', (tester) async {
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Scaffold(body: Text('Settings Screen')),
          ),
          GoRoute(
            path: AppRouter.home,
            builder: (_, _) => const Scaffold(body: Text('Home Screen')),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          currentOrgIdProvider.overrideWithValue('org-test'),
          workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
          channelProvider.overrideWith(() => _FakeChannelNotifier([design])),
          notificationServiceProvider.overrideWith(
            (ref) => NotificationService(
              ref,
              router,
              () async {},
              () async => false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await container.read(channelProvider.future);

      await container
          .read(notificationServiceProvider)
          .handleNotificationClick(
            channelId: 'ch-design',
            senderName: 'Alice',
            senderId: 'user_alice',
            contentPreview: 'Lunch?',
          );
      await tester.pumpAndSettle();

      expect(container.read(homeSidebarProvider), HomeSidebarType.home);
      final chat = container.read(activeChatProvider);
      expect(chat.type, ActiveChatType.channel);
      expect(chat.id, 'design');
      expect(chat.channelId, 'ch-design');
      expect(container.read(selectedDmProvider), isNull);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRouter.home,
      );
    });
  });
}

class _FakeChannelNotifier extends ChannelNotifier {
  _FakeChannelNotifier(this._channels);

  final List<Channel> _channels;

  @override
  Future<List<Channel>> build() async => _channels;
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();

  @override
  Future<void> fetchWorkspaces() async {}
}
