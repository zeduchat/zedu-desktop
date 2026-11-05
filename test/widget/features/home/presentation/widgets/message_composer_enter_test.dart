import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();

  @override
  Future<void> load() async {}
}

void main() {
  Future<List<String>> pumpComposer(
    WidgetTester tester,
    List<String> sent,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileNotifierProvider.overrideWith(_FakeProfileNotifier.new),
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
