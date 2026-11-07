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

Future<void> pumpChatArea(WidgetTester tester) async {
  // History stays loading so the polling that follows a load never starts.
  final repository = MockDmRepository();
  when(
    () => repository.getMessages(any(), page: any(named: 'page')),
  ).thenAnswer((_) => Completer<List<Map<String, dynamic>>>().future);
  final storage = MockSecureStorageService();
  when(() => storage.readData(any())).thenAnswer((_) async => null);

  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

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
}

Finder get composerField => find.descendant(
  of: find.byType(DmMessageComposer),
  matching: find.byType(EditableText),
);

Finder get searchField => find.descendant(
  of: find.byType(SearchPanel),
  matching: find.byType(EditableText),
);

bool hasFocus(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(field).focusNode.hasFocus;

Future<void> pressFind(WidgetTester tester, LogicalKeyboardKey modifier) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(modifier);
  // The panel's field autofocuses on the frame after it is built.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('DmChatArea find shortcut (Ziki #3441)', () {
    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      testWidgets('${modifier.keyLabel}+F opens the search panel with its '
          'field focused', (tester) async {
        await pumpChatArea(tester);
        await tester.tap(composerField);
        await tester.pump();
        expect(find.byType(SearchPanel), findsNothing);

        await pressFind(tester, modifier);

        expect(find.byType(SearchPanel), findsOneWidget);
        expect(hasFocus(tester, searchField), isTrue);
      });
    }

    testWidgets('Ctrl+F with the panel open puts the cursor back in its '
        'field', (tester) async {
      await pumpChatArea(tester);
      await tester.tap(composerField);
      await tester.pump();
      await pressFind(tester, LogicalKeyboardKey.controlLeft);
      await tester.enterText(searchField, 'invoice');
      await tester.tap(composerField);
      await tester.pump();
      expect(hasFocus(tester, searchField), isFalse);

      await pressFind(tester, LogicalKeyboardKey.controlLeft);

      expect(find.byType(SearchPanel), findsOneWidget);
      expect(hasFocus(tester, searchField), isTrue);
      final controller = tester.widget<EditableText>(searchField).controller;
      expect(controller.selection.start, 0);
      expect(controller.selection.end, 'invoice'.length);
    });

    testWidgets('Esc in the search panel closes it and refocuses the message '
        'box', (tester) async {
      await pumpChatArea(tester);
      await tester.tap(composerField);
      await tester.pump();
      await pressFind(tester, LogicalKeyboardKey.controlLeft);
      expect(hasFocus(tester, searchField), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byType(SearchPanel), findsNothing);
      expect(hasFocus(tester, composerField), isTrue);
    });

    testWidgets('the close button also refocuses the message box', (
      tester,
    ) async {
      await pumpChatArea(tester);
      await tester.tap(composerField);
      await tester.pump();
      await pressFind(tester, LogicalKeyboardKey.controlLeft);

      await tester.tap(find.byTooltip('Close search'));
      await tester.pump();

      expect(find.byType(SearchPanel), findsNothing);
      expect(hasFocus(tester, composerField), isTrue);
    });
  });

  testWidgets('the keyboard shortcuts list includes find and Esc', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestMaterialApp(const Scaffold(body: KeyboardShortcutsDialog())),
    );

    expect(find.text('Search this conversation'), findsOneWidget);
    expect(find.text('Close the search panel'), findsOneWidget);
  });
}
