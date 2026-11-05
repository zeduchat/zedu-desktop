import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _MockDmRepository extends Mock implements DmRepository {}

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
  group('DmMessageComposer keeps an unsent reply across edit mode', () {
    late _MockDmRepository repository;
    late DmDraftStore drafts;
    late GlobalKey<DmMessageComposerState> composerKey;

    setUp(() {
      repository = _MockDmRepository();
      when(
        () => repository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => <Map<String, dynamic>>[]);
      when(
        () => repository.editMessage(any(), content: any(named: 'content')),
      ).thenAnswer((_) async {});
      when(
        () => repository.sendMessage(
          any(),
          any(),
          media: any(named: 'media'),
          mentions: any(named: 'mentions'),
          isChannel: any(named: 'isChannel'),
        ),
      ).thenAnswer((_) async => 'thread-1');
      drafts = DmDraftStore(_MemoryStorage(), userId: 'user-1', orgId: 'org-1');
      composerKey = GlobalKey<DmMessageComposerState>();
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
            dmRepositoryProvider.overrideWithValue(repository),
            dmDraftStoreProvider.overrideWith((ref) => drafts),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: DmMessageComposer(
                key: composerKey,
                recipientName: 'Ada',
                channelId: 'channel-1',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    TextEditingController controller(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText)).controller;

    Future<void> typeReplyAndEdit(WidgetTester tester) async {
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'half a reply');
      await tester.pump();
      composerKey.currentState!.enterEditMode('message-1', 'old message');
      await tester.pump();
      expect(controller(tester).text, 'old message');
    }

    testWidgets('cancelling the edit gives the reply back', (tester) async {
      await pump(tester);
      await typeReplyAndEdit(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(controller(tester).text, 'half a reply');
    });

    testWidgets('saving the edit gives the reply back and keeps its draft', (
      tester,
    ) async {
      await pump(tester);
      await typeReplyAndEdit(tester);

      await tester.enterText(find.byType(TextField), 'edited message');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => repository.editMessage(any(), content: 'edited message'),
      ).called(1);
      expect(controller(tester).text, 'half a reply');
      expect((await drafts.load('channel-1'))?.text, 'half a reply');
    });

    testWidgets('the reply is saved as a draft as soon as editing starts', (
      tester,
    ) async {
      await pump(tester);
      // Editing starts before the 250 ms debounced draft save would run.
      await typeReplyAndEdit(tester);

      expect((await drafts.load('channel-1'))?.text, 'half a reply');
      await tester.pump(const Duration(milliseconds: 300));
      expect((await drafts.load('channel-1'))?.text, 'half a reply');
    });

    testWidgets('a normal send still clears the box and the draft', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump(const Duration(milliseconds: 300));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller(tester).text, isEmpty);
      expect(await drafts.load('channel-1'), isNull);
    });
  });
}
