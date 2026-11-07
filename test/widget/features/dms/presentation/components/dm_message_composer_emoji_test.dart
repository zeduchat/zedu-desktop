import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

Widget _composer({bool isChannel = false}) {
  final storage = _MockSecureStorageService();
  when(() => storage.readData(any())).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(storage, userId: 'u', orgId: 'o'),
      ),
    ],
    child: buildTestMaterialApp(
      Scaffold(
        body: DmMessageComposer(
          recipientName: 'Ada',
          channelId: 'channel-1',
          isChannel: isChannel,
        ),
      ),
    ),
  );
}

void main() {
  TextEditingController controllerOf(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller;

  Future<void> showComposer(
    WidgetTester tester, {
    bool isChannel = false,
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_composer(isChannel: isChannel));
    await tester.pump();
  }

  Future<String> pickEmoji(WidgetTester tester, TextEditingValue value) async {
    await showComposer(tester);
    controllerOf(tester).value = value;
    await tester.pump();

    await tester.tap(find.byTooltip('Emoji (Ctrl/Cmd+Shift+E)'));
    await tester.pump();
    final picker = tester.widget<DmEmojiPicker>(find.byType(DmEmojiPicker));
    picker.onEmojiSelected('😀');
    await tester.pump();
    return controllerOf(tester).text;
  }

  testWidgets('replaces the highlighted word', (tester) async {
    final text = await pickEmoji(
      tester,
      const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 6, extentOffset: 11),
      ),
    );

    expect(text, 'hello 😀');
    expect(controllerOf(tester).selection.isCollapsed, isTrue);
    expect(controllerOf(tester).selection.baseOffset, 'hello 😀'.length);
  });

  testWidgets('replaces a selection dragged backwards', (tester) async {
    final text = await pickEmoji(
      tester,
      const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 11, extentOffset: 6),
      ),
    );

    expect(text, 'hello 😀');
  });

  testWidgets('inserts at the cursor when nothing is highlighted', (
    tester,
  ) async {
    final text = await pickEmoji(
      tester,
      const TextEditingValue(
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );

    expect(text, 'hello😀 world');
  });

  testWidgets('opens from the composer and selects with arrow keys and Enter', (
    tester,
  ) async {
    await showComposer(tester, isChannel: true);
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.byType(DmEmojiPicker), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controllerOf(tester).text, '\u{1F603}');
  });

  testWidgets('Escape closes the picker and restores composer focus', (
    tester,
  ) async {
    await showComposer(tester);
    await tester.tap(find.byTooltip('Emoji (Ctrl/Cmd+Shift+E)'));
    await tester.pump();
    expect(find.byType(DmEmojiPicker), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byType(DmEmojiPicker), findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('mouse selection still inserts an emoji', (tester) async {
    await showComposer(tester);
    await tester.tap(find.byTooltip('Emoji (Ctrl/Cmd+Shift+E)'));
    await tester.pump();

    await tester.tap(find.text('\u{1F600}').first);
    await tester.pump();

    expect(controllerOf(tester).text, '\u{1F600}');
  });
}
