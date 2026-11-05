import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('NotificationService handleNotificationClick', () {
    GoRouter createTestRouter({String initialLocation = '/settings'}) =>
        GoRouter(
          initialLocation: initialLocation,
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

    testWidgets(
      'selects existing conversation from dmListProvider, sets sidebar to dms, and navigates to home',
      (tester) async {
        final router = createTestRouter(initialLocation: '/settings');
        final container = ProviderContainer(
          overrides: [
            dmListProvider.overrideWith(
              () => _FakeDmListNotifier([
                DmConversation(
                  channelId: 'channel_123',
                  username: 'Alice',
                  participantId: 'user_alice',
                  previewMessage: 'Existing preview',
                  unreadCount: 1,
                ),
              ]),
            ),
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
        await container.read(dmListProvider.future);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/settings',
        );

        final service = container.read(notificationServiceProvider);

        await service.handleNotificationClick(
          channelId: 'channel_123',
          senderName: 'Alice',
          senderId: 'user_alice',
          contentPreview: 'Hey there!',
        );
        await tester.pumpAndSettle();

        expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
        final selected = container.read(selectedDmProvider);
        expect(selected, isNotNull);
        expect(selected!.channelId, 'channel_123');
        expect(selected.username, 'Alice');
        expect(selected.previewMessage, 'Existing preview');
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRouter.home,
        );
      },
    );

    testWidgets(
      'creates fallback DmConversation when channel is not in dmListProvider',
      (tester) async {
        final router = createTestRouter(initialLocation: '/settings');
        final container = ProviderContainer(
          overrides: [
            dmListProvider.overrideWith(() => _FakeDmListNotifier([])),
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

        final service = container.read(notificationServiceProvider);

        await service.handleNotificationClick(
          channelId: 'channel_456',
          senderName: 'Bob',
          senderId: 'user_bob',
          contentPreview: 'New DM message',
        );
        await tester.pumpAndSettle();

        expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
        final selected = container.read(selectedDmProvider);
        expect(selected, isNotNull);
        expect(selected!.channelId, 'channel_456');
        expect(selected.username, 'Bob');
        expect(selected.participantId, 'user_bob');
        expect(selected.previewMessage, 'New DM message');
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRouter.home,
        );
      },
    );

    testWidgets(
      'does not throw or duplicate navigation if already on home screen',
      (tester) async {
        final router = createTestRouter(initialLocation: AppRouter.home);
        final container = ProviderContainer(
          overrides: [
            dmListProvider.overrideWith(() => _FakeDmListNotifier([])),
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
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRouter.home,
        );

        final service = container.read(notificationServiceProvider);

        await service.handleNotificationClick(
          channelId: 'channel_789',
          senderName: 'Charlie',
          senderId: 'user_charlie',
          contentPreview: 'Hello',
        );
        await tester.pumpAndSettle();

        expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
        expect(container.read(selectedDmProvider)?.channelId, 'channel_789');
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRouter.home,
        );
      },
    );
  });
}

class _FakeDmListNotifier extends AsyncNotifier<List<DmConversation>>
    implements DmListNotifier {
  final List<DmConversation> _items;

  _FakeDmListNotifier(this._items);

  @override
  bool get hasMore => false;

  @override
  Future<List<DmConversation>> build() async => _items;

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {
    state = AsyncData(_items);
  }
}
