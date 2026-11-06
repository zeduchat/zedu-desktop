import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockSavedRepository extends Mock implements SavedRepository {}

class MockReminderRepository extends Mock implements ReminderRepository {}

class FakeSignedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'test-org',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

SavedMessage savedRow({
  required String channelId,
  required String threadId,
}) => SavedMessage(
  id: 'saved-1',
  target: SavedTarget(channelId: channelId, threadId: threadId),
  kind: SavedMessageKind.thread,
  authorName: 'Bola',
  content: 'from them',
  savedAt: DateTime(2026, 11, 6, 8),
);

/// A reminder repository that reports nothing pending.
MockReminderRepository emptyReminders() {
  final repository = MockReminderRepository();
  when(
    () => repository.list(orgId: any(named: 'orgId')),
  ).thenAnswer((_) async => <MessageReminder>[]);
  return repository;
}

/// Loads the saved list, as the Home sidebar does when it mounts.
Future<void> loadSaved(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold)),
  );
  await container.read(savedProvider.notifier).refresh();
  await tester.pumpAndSettle();
}

void main() {
  group('direct messages', () {
    Future<void> pumpDm(
      WidgetTester tester, {
      List<SavedMessage> saved = const [],
      String senderId = 'u-2',
    }) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockDmRepository();
      when(
        () => repository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => [
          {
            'id': 'm1',
            'content': 'from them',
            'user_id': senderId,
            'created_at': '2026-11-06T08:00:00Z',
          },
        ],
      );
      final storage = MockSecureStorageService();
      when(() => storage.readData(any())).thenAnswer((_) async => null);
      when(() => storage.writeData(any(), any())).thenAnswer((_) async {});

      final savedRepository = MockSavedRepository();
      when(
        () => savedRepository.list(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => saved);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(FakeSignedInAuthNotifier.new),
            dmRepositoryProvider.overrideWithValue(repository),
            savedRepositoryProvider.overrideWithValue(savedRepository),
            reminderRepositoryProvider.overrideWithValue(emptyReminders()),
            currentOrgIdProvider.overrideWithValue('org-1'),
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(storage, userId: 'user-1', orgId: 'org-1'),
            ),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: DmChatArea(
                conversation: DmConversation(
                  channelId: 'dm-1',
                  username: 'Bola',
                  participantId: 'u-2',
                  previewMessage: '',
                  unreadCount: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The Home sidebar loads the saved list once per workspace; these tests
      // mount the chat area alone, so they do it explicitly.
      await loadSaved(tester);
    }

    testWidgets('another person\'s message can be saved and reminded about', (
      tester,
    ) async {
      await pumpDm(tester);

      // Before this change other people's messages had no menu at all.
      await tester.tap(find.byTooltip('Message actions').first);
      await tester.pumpAndSettle();

      expect(find.text('Save for later'), findsOneWidget);
      expect(find.text('Remind me about this'), findsOneWidget);
      // Not the author's own message, so these stay out.
      expect(find.text('Edit message'), findsNothing);
      expect(find.text('Delete message'), findsNothing);
    });

    testWidgets('a saved message offers to be removed instead', (tester) async {
      await pumpDm(
        tester,
        saved: [savedRow(channelId: 'dm-1', threadId: 'm1')],
      );

      await tester.tap(find.byTooltip('Message actions').first);
      await tester.pumpAndSettle();

      expect(find.text('Remove from saved'), findsOneWidget);
      expect(find.text('Save for later'), findsNothing);
    });

    testWidgets('the author keeps Edit and Delete alongside the new entries', (
      tester,
    ) async {
      await pumpDm(tester, senderId: 'user-1');

      await tester.tap(find.byTooltip('Message actions').first);
      await tester.pumpAndSettle();

      expect(find.text('Edit message'), findsOneWidget);
      expect(find.text('Delete message'), findsOneWidget);
      expect(find.text('Save for later'), findsOneWidget);
      expect(find.text('Remind me about this'), findsOneWidget);
    });
  });

  group('channels', () {
    Future<void> pumpChannelTile(
      WidgetTester tester, {
      List<SavedMessage> saved = const [],
      String? channelId = 'chan-1',
      String? messageId = 'cm-1',
      String? status,
    }) async {
      final savedRepository = MockSavedRepository();
      when(
        () => savedRepository.list(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => saved);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRepositoryProvider.overrideWithValue(savedRepository),
            reminderRepositoryProvider.overrideWithValue(emptyReminders()),
            currentOrgIdProvider.overrideWithValue('org-1'),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: ChannelMessageTile(
                channelId: channelId,
                message: ChannelMessage(
                  id: messageId,
                  senderName: 'Ada',
                  text: 'Deadline is Friday',
                  createdAt: DateTime(2026, 11, 6, 8),
                  status: status,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await loadSaved(tester);
    }

    testWidgets('a channel message can be saved and reminded about', (
      tester,
    ) async {
      await pumpChannelTile(tester);

      await tester.tap(find.byTooltip('Message actions'));
      await tester.pumpAndSettle();

      expect(find.text('Save for later'), findsOneWidget);
      expect(find.text('Remind me about this'), findsOneWidget);
    });

    testWidgets('a saved channel message offers to be removed', (tester) async {
      await pumpChannelTile(
        tester,
        saved: [savedRow(channelId: 'chan-1', threadId: 'cm-1')],
      );

      await tester.tap(find.byTooltip('Message actions'));
      await tester.pumpAndSettle();

      expect(find.text('Remove from saved'), findsOneWidget);
    });

    testWidgets('a message still sending has no menu, having no server id', (
      tester,
    ) async {
      await pumpChannelTile(tester, status: 'sending');

      expect(find.byTooltip('Message actions'), findsNothing);
      expect(find.text('Deadline is Friday'), findsOneWidget);
    });

    testWidgets('a tile without a channel id has no menu', (tester) async {
      await pumpChannelTile(tester, channelId: null);

      expect(find.byTooltip('Message actions'), findsNothing);
    });
  });
}
