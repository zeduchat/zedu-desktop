import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class MockDmRepository extends Mock implements DmRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

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

void main() {
  testWidgets('DmChatArea header has no test notification button', (
    tester,
  ) async {
    // History stays loading so the polling that follows a load never starts.
    final repository = MockDmRepository();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) => Completer<List<Map<String, dynamic>>>().future);
    final storage = MockSecureStorageService();
    when(() => storage.readData(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(FakeAuthNotifier.new),
          dmRepositoryProvider.overrideWithValue(repository),
          dmDraftStoreProvider.overrideWith(
            (ref) => DmDraftStore(storage, userId: 'u', orgId: 'o'),
          ),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: DmChatArea(
              conversation: DmConversation(
                channelId: 'channel-1',
                username: 'Bola',
                participantId: 'user-2',
                previewMessage: '',
                unreadCount: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.byTooltip('Test Notification (Delayed 5s)'), findsNothing);
  });

  testWidgets(
    'deleting a DM discards its draft, even when the composer closes',
    (tester) async {
      final repository = MockDmRepository();
      when(
        () => repository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) => Completer<List<Map<String, dynamic>>>().future);
      when(
        () => repository.deleteConversation(
          orgId: any(named: 'orgId'),
          channelId: any(named: 'channelId'),
        ),
      ).thenAnswer((_) async {});
      final storage = MockSecureStorageService();
      when(() => storage.readData(any())).thenAnswer((_) async => null);
      when(() => storage.writeData(any(), any())).thenAnswer((_) async {});
      when(() => storage.deleteValue(any())).thenAnswer((_) async {});
      // The history spinner never stops, so pumpAndSettle would time out.
      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(FakeAuthNotifier.new),
            currentOrgIdProvider.overrideWithValue('org-1'),
            dmRepositoryProvider.overrideWithValue(repository),
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(storage, userId: 'u', orgId: 'org-1'),
            ),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: DmChatArea(
                conversation: DmConversation(
                  channelId: 'channel-1',
                  username: 'Bola',
                  participantId: 'user-2',
                  previewMessage: '',
                  unreadCount: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'unsent text');
      await tester.tap(find.byTooltip('More options'));
      await settle();
      await tester.tap(find.text('Delete conversation'));
      await settle();
      // From here on, nothing may write the draft back.
      clearInteractions(storage);
      await tester.tap(find.widgetWithText(TextButton, 'Delete conversation'));
      await settle();

      verify(
        () => repository.deleteConversation(
          orgId: 'org-1',
          channelId: 'channel-1',
        ),
      ).called(1);

      // Close the composer, then let any deferred save run.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      verify(() => storage.deleteValue('dm_draft_u_org-1_channel-1')).called(1);
      verifyNever(() => storage.writeData(any(), any()));
    },
  );

  testWidgets(
    'Clear history shows a cleared note, not the start-of-conversation card',
    (tester) async {
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
            'content': 'old message',
            'user_id': 'u-2',
            'created_at': '2026-10-17T08:00:00Z',
          },
        ],
      );
      final storage = MockSecureStorageService();
      when(() => storage.readData(any())).thenAnswer((_) async => null);
      when(() => storage.writeData(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmRepositoryProvider.overrideWithValue(repository),
            authNotifierProvider.overrideWith(FakeSignedInAuthNotifier.new),
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(storage, userId: 'user-1', orgId: 'org-1'),
            ),
            dmHistoryClearStoreProvider.overrideWithValue(
              DmHistoryClearStore(storage, userId: 'user-1'),
            ),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: DmChatArea(
                conversation: DmConversation(
                  channelId: 'ch-1',
                  username: 'Ada Lovelace',
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
      expect(find.text('View Profile'), findsOneWidget);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear history'));
      await tester.pumpAndSettle();

      expect(find.text('old message', findRichText: true), findsNothing);
      expect(find.text('View Profile'), findsNothing);
      expect(find.text('History cleared on this device'), findsOneWidget);
      verify(
        () => storage.writeData(
          'dm_history_cleared_user-1_ch-1',
          '2026-10-17T08:00:00.000Z',
        ),
      ).called(1);
    },
  );

  group('DmChatArea message text', () {
    Future<void> pumpChat(
      WidgetTester tester,
      List<Map<String, dynamic>> messages,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockDmRepository();
      when(
        () => repository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => messages);
      final storage = MockSecureStorageService();
      when(() => storage.readData(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmRepositoryProvider.overrideWithValue(repository),
            authNotifierProvider.overrideWith(FakeSignedInAuthNotifier.new),
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(storage, userId: 'user-1', orgId: 'org-1'),
            ),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: DmChatArea(
                conversation: DmConversation(
                  channelId: 'ch-1',
                  username: 'Ada Lovelace',
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
    }

    testWidgets('own space explains privacy and hides its system event', (
      tester,
    ) async {
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
            'id': 'system-1',
            'type': 'system',
            'content': 'You started a conversation with yourself',
            'created_at': '2026-10-17T08:00:00Z',
          },
          {
            'id': 'note-1',
            'type': 'user',
            'content': 'A private note',
            'user_id': 'user-1',
            'created_at': '2026-10-17T08:01:00Z',
          },
        ],
      );
      final storage = MockSecureStorageService();
      when(() => storage.readData(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(FakeSignedInAuthNotifier.new),
            dmRepositoryProvider.overrideWithValue(repository),
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(storage, userId: 'user-1', orgId: 'org-1'),
            ),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: DmChatArea(
                conversation: DmConversation(
                  channelId: 'own-space',
                  username: 'Test User',
                  participantId: 'user-1',
                  previewMessage: '',
                  unreadCount: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OwnSpaceIntro), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('Only you can see this.'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('Test User (you)'),
        ),
        findsNWidgets(2),
      );
      expect(find.text('A private note', findRichText: true), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains(
                'You started a conversation with yourself',
              ),
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .decoration!
            .hintText,
        'Write a note to yourself',
      );
      expect(find.text('Edit profile'), findsOneWidget);
    });

    testWidgets('other DMs retain their regular intro and composer hint', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockDmRepository();
      when(
        () => repository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => []);
      final storage = MockSecureStorageService();
      when(() => storage.readData(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(FakeSignedInAuthNotifier.new),
            dmRepositoryProvider.overrideWithValue(repository),
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(storage, userId: 'user-1', orgId: 'org-1'),
            ),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: DmChatArea(
                conversation: DmConversation(
                  channelId: 'other-dm',
                  username: 'Bola',
                  participantId: 'user-2',
                  previewMessage: '',
                  unreadCount: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bola'), findsWidgets);
      expect(find.text('Edit profile'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .decoration!
            .hintText,
        startsWith('Message @Bola'),
      );
    });

    Map<String, dynamic> message(String id, String content) => {
      'id': id,
      'content': content,
      'user_id': 'u-2',
      'created_at': '2026-10-17T08:00:00Z',
    };

    Map<String, dynamic> ownMessage(String id, String content) => {
      'id': id,
      'content': content,
      'user_id': 'user-1',
      'created_at': '2026-10-17T08:00:00Z',
    };

    Future<void> searchFor(WidgetTester tester, String query) async {
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search in conversation'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        query,
      );
      await tester.pumpAndSettle();
    }

    Finder searchResult(String text) =>
        find.descendant(of: find.byType(ListTile), matching: find.text(text));

    testWidgets('search shows results without HTML tags', (tester) async {
      await pumpChat(tester, [
        message('m1', '<p>hello <strong>team</strong></p>'),
      ]);

      await searchFor(tester, 'team');

      expect(searchResult('hello team'), findsOneWidget);
    });

    testWidgets('search does not match tag names', (tester) async {
      await pumpChat(tester, [
        message('m1', '<p>hello <strong>team</strong></p>'),
      ]);

      await searchFor(tester, 'strong');

      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('search finds and shows decoded special characters', (
      tester,
    ) async {
      await pumpChat(tester, [message('m1', '<p>Tom &amp; Jerry &lt;3</p>')]);

      await searchFor(tester, 'tom & jerry');

      expect(searchResult('Tom & Jerry <3'), findsOneWidget);
    });

    testWidgets('opens the message menu on long press', (tester) async {
      await pumpChat(tester, [ownMessage('m1', 'my message')]);

      await tester.longPress(find.text('my message', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.text('Edit message'), findsOneWidget);
      expect(find.text('Delete message'), findsOneWidget);
    });

    testWidgets('Edit message from the menu puts the message in the composer', (
      tester,
    ) async {
      await pumpChat(tester, [ownMessage('m1', 'my message')]);

      await tester.longPress(find.text('my message', findRichText: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit message'));
      await tester.pumpAndSettle();

      expect(find.text('Editing message'), findsOneWidget);
      final composer = tester.widget<TextField>(find.byType(TextField).last);
      expect(composer.controller!.text, 'my message');
    });

    testWidgets('shows no text for a message with an empty paragraph', (
      tester,
    ) async {
      await pumpChat(tester, [message('m1', '<p></p>')]);

      expect(find.text('<p></p>', findRichText: true), findsNothing);
    });

    testWidgets('still shows the text of a normal message', (tester) async {
      await pumpChat(tester, [message('m1', 'hello there')]);

      expect(find.text('hello there', findRichText: true), findsOneWidget);
    });

    testWidgets('shows a message sent from web without its HTML tags', (
      tester,
    ) async {
      await pumpChat(tester, [
        message('m1', '<p>Tom &amp; <strong>Jerry</strong></p>'),
      ]);

      expect(find.text('Tom & Jerry', findRichText: true), findsOneWidget);
      expect(find.textContaining('<p>', findRichText: true), findsNothing);
      final bold = find.byWidgetPredicate((widget) {
        if (widget is! RichText) return false;
        var isBold = false;
        widget.text.visitChildren((span) {
          if (span is TextSpan &&
              span.text == 'Jerry' &&
              span.style?.fontWeight == FontWeight.bold) {
            isBold = true;
          }
          return true;
        });
        return isBold;
      });
      expect(bold, findsOneWidget);
    });

    testWidgets('editing a web message puts its text, not HTML, in the box', (
      tester,
    ) async {
      await pumpChat(tester, [ownMessage('m1', '<p>my message</p>')]);

      await tester.longPress(find.text('my message', findRichText: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit message'));
      await tester.pumpAndSettle();

      final composer = tester.widget<TextField>(find.byType(TextField).last);
      expect(composer.controller!.text, 'my message');
    });

    testWidgets('opens a URL in a message when it is tapped', (tester) async {
      final opened = <Uri>[];
      final original = messageLinkLauncher;
      messageLinkLauncher = (uri) async {
        opened.add(uri);
        return true;
      };
      addTearDown(() => messageLinkLauncher = original);

      await pumpChat(tester, [message('m1', 'https://example.com/dm')]);
      await tester.tap(find.text('https://example.com/dm', findRichText: true));
      await tester.pump();

      expect(opened, [Uri.parse('https://example.com/dm')]);
    });

    testWidgets('opens a URL inside bold text', (tester) async {
      final opened = <Uri>[];
      final original = messageLinkLauncher;
      messageLinkLauncher = (uri) async {
        opened.add(uri);
        return true;
      };
      addTearDown(() => messageLinkLauncher = original);

      await pumpChat(tester, [message('m1', '**https://example.com/bold**')]);
      await tester.tap(
        find.text('https://example.com/bold', findRichText: true),
      );
      await tester.pump();

      expect(opened, [Uri.parse('https://example.com/bold')]);
    });

    Finder bubbleDividers(String text) => find.descendant(
      of: find
          .ancestor(
            of: find.text(text, findRichText: true),
            matching: find.byType(IntrinsicWidth),
          )
          .first,
      matching: find.byType(Divider),
    );

    testWidgets('draws a divider line for a --- line after a blank line', (
      tester,
    ) async {
      await pumpChat(tester, [message('m1', 'hello\n\n---\nworld')]);

      expect(find.text('hello', findRichText: true), findsOneWidget);
      expect(find.text('world', findRichText: true), findsOneWidget);
      expect(find.textContaining('---', findRichText: true), findsNothing);
      expect(bubbleDividers('hello'), findsOneWidget);
    });

    testWidgets('draws the divider the composer inserts into an empty box', (
      tester,
    ) async {
      await pumpChat(tester, [message('m1', '---\nworld')]);

      expect(find.text('world', findRichText: true), findsOneWidget);
      expect(find.textContaining('---', findRichText: true), findsNothing);
      expect(bubbleDividers('world'), findsOneWidget);
    });

    testWidgets('keeps --- straight under text as text, as Markdown does', (
      tester,
    ) async {
      await pumpChat(tester, [message('m1', 'hello\n---')]);

      expect(find.text('hello\n---', findRichText: true), findsOneWidget);
      expect(find.byType(IntrinsicWidth), findsNothing);
    });
  });
}
