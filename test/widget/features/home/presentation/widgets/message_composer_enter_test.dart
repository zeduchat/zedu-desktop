import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();

  @override
  Future<void> load() async {}
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

void main() {
  late _MockDmRepository repository;

  setUp(() {
    repository = _MockDmRepository();
    final storage = _MockStorage();
    locator.registerSingleton<SecureStorageService>(storage);
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => const []);
    when(
      () => repository.sendMessage(
        any(),
        any(),
        media: any(named: 'media'),
        mentions: any(named: 'mentions'),
        isChannel: any(named: 'isChannel'),
      ),
    ).thenAnswer((_) async => 'thread-id');
  });

  tearDown(() => locator.reset());

  Future<List<String>> pumpComposer(
    WidgetTester tester,
    List<String> sent,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileNotifierProvider.overrideWith(_FakeProfileNotifier.new),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          dmRepositoryProvider.overrideWithValue(repository),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: MessageComposer(
              activeChat: ActiveChatState.generalChannel,
              onSend: sent.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    return sent;
  }

  String composerText(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  group('MessageComposer Enter keys', () {
    testWidgets('plain Enter sends the message', (tester) async {
      final sent = await pumpComposer(tester, []);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(sent, ['hello']);
    });

    testWidgets('Shift+Enter inserts a line break and does not send', (
      tester,
    ) async {
      final sent = await pumpComposer(tester, []);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(sent, isEmpty);
      expect(composerText(tester), 'hello');
    });

    testWidgets('Ctrl+Enter also sends the message', (tester) async {
      final sent = await pumpComposer(tester, []);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(sent, ['hello']);
    });
  });
}
