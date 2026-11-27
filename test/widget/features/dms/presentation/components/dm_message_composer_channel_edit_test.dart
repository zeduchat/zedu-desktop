import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockChannelRepository extends Mock implements ChannelRepository {}

class _FakeAuthNotifier extends AuthNotifier {
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
      currentOrganisationSlug: 'org-slug',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

class _MemoryStorage extends Fake implements SecureStorageService {
  final values = <String, String>{};

  @override
  Future<String?> readData(String key) async => values[key];

  @override
  Future<void> writeData(String key, String value) async => values[key] = value;

  @override
  Future<void> deleteValue(String key) async => values.remove(key);
}

void main() {
  group(
    'DmMessageComposer edits channel messages with the Up arrow (#3440)',
    () {
      late _MockDmRepository dmRepository;
      late _MockChannelRepository channelRepository;
      late DmDraftStore drafts;

      // Newest first, as the channel history is.
      final history = <ChannelMessage>[
        const ChannelMessage(
          id: 'm3',
          senderName: 'Ada',
          text: 'someone else, newest',
          threadId: 'thread-3',
          userId: 'user-2',
        ),
        const ChannelMessage(
          id: 'm2',
          senderName: 'Test User',
          text: 'my latest message',
          threadId: 'thread-2',
          userId: 'user-1',
        ),
        const ChannelMessage(
          id: 'm1',
          senderName: 'Test User',
          text: 'my older message',
          threadId: 'thread-1',
          userId: 'user-1',
        ),
      ];

      setUp(() {
        dmRepository = _MockDmRepository();
        channelRepository = _MockChannelRepository();
        when(
          () => dmRepository.getMessages(any(), page: any(named: 'page')),
        ).thenAnswer((_) async => <Map<String, dynamic>>[]);
        when(
          () => dmRepository.editMessage(any(), content: any(named: 'content')),
        ).thenAnswer((_) async {});
        when(
          () => channelRepository.fetchChannelMessages(
            any(),
            page: any(named: 'page'),
          ),
        ).thenAnswer(
          (_) async =>
              Success(ChannelMessagePage(messages: history, hasMore: false)),
        );
        when(
          () => channelRepository.editChannelMessage(
            channelId: any(named: 'channelId'),
            threadId: any(named: 'threadId'),
            content: any(named: 'content'),
          ),
        ).thenAnswer((_) async => const Success<void>(null));
        drafts = DmDraftStore(
          _MemoryStorage(),
          userId: 'user-1',
          orgId: 'org-1',
        );
      });

      Future<ProviderContainer> pump(
        WidgetTester tester, {
        bool isChannel = true,
      }) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
              dmRepositoryProvider.overrideWithValue(dmRepository),
              channelRepositoryProvider.overrideWithValue(channelRepository),
              dmDraftStoreProvider.overrideWith((ref) => drafts),
            ],
            child: buildTestMaterialApp(
              Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    // The channel screen keeps its history loaded.
                    ref.watch(channelHistoryProvider('channel-1'));
                    return DmMessageComposer(
                      recipientName: 'general',
                      channelId: 'channel-1',
                      isChannel: isChannel,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        return ProviderScope.containerOf(
          tester.element(find.byType(DmMessageComposer)),
        );
      }

      TextEditingController controller(WidgetTester tester) =>
          tester.widget<EditableText>(find.byType(EditableText)).controller;

      testWidgets('Up opens my latest channel message, not someone else\'s', (
        tester,
      ) async {
        await pump(tester);
        await tester.tap(find.byType(TextField));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(controller(tester).text, 'my latest message');
      });

      testWidgets('saving goes through the thread route, not the DM route', (
        tester,
      ) async {
        final container = await pump(tester);
        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'my edited message');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => channelRepository.editChannelMessage(
            channelId: 'channel-1',
            threadId: 'thread-2',
            content: 'my edited message',
          ),
        ).called(1);
        verifyNever(
          () => dmRepository.editMessage(any(), content: any(named: 'content')),
        );
        // The edit shows in the loaded history straight away, without a
        // refetch that could still return the old text (Ziki #12383).
        final messages = container
            .read(channelHistoryProvider('channel-1'))
            .requireValue
            .messages;
        expect(
          messages.firstWhere((m) => m.threadId == 'thread-2').text,
          'my edited message',
        );
        verify(
          () => channelRepository.fetchChannelMessages(
            'channel-1',
            page: any(named: 'page'),
          ),
        ).called(1);
      });

      testWidgets('Up does nothing when I have no message in the channel', (
        tester,
      ) async {
        when(
          () => channelRepository.fetchChannelMessages(
            any(),
            page: any(named: 'page'),
          ),
        ).thenAnswer(
          (_) async => Success(
            ChannelMessagePage(messages: [history.first], hasMore: false),
          ),
        );
        await pump(tester);
        await tester.tap(find.byType(TextField));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(controller(tester).text, isEmpty);
      });
    },
  );
}
