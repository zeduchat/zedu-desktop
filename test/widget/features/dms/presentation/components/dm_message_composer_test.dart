import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class FakeSecureStorageService extends Fake implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> readData(String key) async => _values[key];

  @override
  Future<void> writeData(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);
}

class _VirtualAttachment extends Fake implements XFile {
  @override
  String get path => 'virtual-attachment.txt';

  @override
  String get name => 'virtual-attachment.txt';

  @override
  Future<int> length() async => 4;
}

class _ComposerFiles extends ComposerFileStore {
  final inspected = <String>[];

  @override
  Future<Result<bool>> exists(String path) async {
    inspected.add(path);
    return const Success(true);
  }
}

Future<TextField> pumpComposer(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dmDraftStoreProvider.overrideWith(
          (ref) => DmDraftStore(
            FakeSecureStorageService(),
            userId: 'user-1',
            orgId: 'org-1',
          ),
        ),
      ],
      child: buildTestMaterialApp(
        const Scaffold(
          body: DmMessageComposer(recipientName: 'Ada', channelId: 'dm-1'),
        ),
      ),
    ),
  );
  return tester.widget<TextField>(find.byType(TextField));
}

Future<void> typeAndPlaceCursorAtEnd(
  WidgetTester tester,
  TextField field,
  String text,
) async {
  await tester.enterText(find.byType(TextField), text);
  field.controller!.selection = TextSelection.collapsed(offset: text.length);
  await tester.pump();
}

/// Runs [body] against the composer, then empties it so the composer's
/// draft flush in `dispose` has nothing to save when the test unmounts it.
void composerTest(
  String description,
  Future<void> Function(WidgetTester tester, TextField field) body,
) {
  testWidgets(description, (tester) async {
    final field = await pumpComposer(tester);
    await body(tester, field);
    field.controller!.clear();
    await tester.pump(const Duration(milliseconds: 300));
  });
}

Future<void> tapDivider(WidgetTester tester) async {
  // Divider lives in the plus menu with the other less-used actions.
  await tester.tap(find.byTooltip('More actions'));
  await tester.pump();
  await tester.tap(find.byTooltip('Divider'));
  // Let the composer's debounced draft save run.
  await tester.pump(const Duration(milliseconds: 300));
}

Widget buildComposerUnderTest() {
  return ProviderScope(
    overrides: [
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(
          FakeSecureStorageService(),
          userId: 'user-1',
          orgId: 'org-1',
        ),
      ),
    ],
    child: buildTestMaterialApp(
      const Scaffold(
        body: DmMessageComposer(
          recipientName: 'Ada',
          channelId: 'channel-1',
          participants: [],
        ),
      ),
    ),
  );
}

TextEditingController composerController(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller;

Future<void> typeAndSelect(
  WidgetTester tester,
  String text, {
  TextSelection? selection,
}) async {
  await tester.tap(find.byType(TextField));
  await tester.enterText(find.byType(TextField), text);
  composerController(tester).selection =
      selection ?? TextSelection(baseOffset: 0, extentOffset: text.length);
  await tester.pump();
}

Future<void> pressShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  LogicalKeyboardKey modifier = LogicalKeyboardKey.controlLeft,
}) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

void main() {
  testWidgets('attachment checks go through the file store without disk I/O', (
    tester,
  ) async {
    final files = _ComposerFiles();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          composerFileStoreProvider.overrideWithValue(files),
          dmDraftStoreProvider.overrideWith(
            (ref) => DmDraftStore(
              FakeSecureStorageService(),
              userId: 'user-1',
              orgId: 'org-1',
            ),
          ),
        ],
        child: buildTestMaterialApp(
          const Scaffold(
            body: DmMessageComposer(recipientName: 'Ada', channelId: 'dm-1'),
          ),
        ),
      ),
    );
    await tester
        .state<DmMessageComposerState>(find.byType(DmMessageComposer))
        .addFiles([_VirtualAttachment()]);
    await tester.pump();

    expect(files.inspected, ['virtual-attachment.txt']);
    expect(find.text('virtual-attachment.txt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('DmMessageComposer block quotes', () {
    const cases = [
      (
        name: 'quotes every selected line across paragraphs',
        text:
            'The meeting starts at 10 AM.\nPlease join five minutes early.\n\n'
            'Bring your project updates.\nWe will review them together.',
        selection: null,
        expected:
            '> The meeting starts at 10 AM.\n> Please join five minutes early.\n> \n'
            '> Bring your project updates.\n> We will review them together.',
        cursor: null,
      ),
      (
        name: 'preserves text outside a reversed multiline selection',
        text: 'Before\nfirst\n\nlast\nAfter',
        selection: TextSelection(baseOffset: 18, extentOffset: 7),
        expected: 'Before\n> first\n> \n> last\nAfter',
        cursor: 24,
      ),
      (
        name: 'preserves text outside a selection within lines',
        text: 'before first\nlast after',
        selection: TextSelection(baseOffset: 7, extentOffset: 17),
        expected: 'before > first\n> last after',
        cursor: 21,
      ),
      (
        name:
            'does not quote the next line when the selection ends in a newline',
        text: 'first\nsecond\nthird',
        selection: TextSelection(baseOffset: 0, extentOffset: 13),
        expected: '> first\n> second\nthird',
        cursor: 17,
      ),
      (
        name: 'quotes one selected line that ends in a newline',
        text: 'one\ntwo',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
        expected: '> one\ntwo',
        cursor: 6,
      ),
      (
        name: 'continues to quote a single line',
        text: 'hello',
        selection: null,
        expected: '> hello',
        cursor: null,
      ),
      (
        name: 'prefixes the line when the cursor is in the middle of it',
        text: 'before after',
        selection: TextSelection.collapsed(offset: 7),
        expected: '> before after',
        cursor: 9,
      ),
      (
        name: 'prefixes the line when the cursor is at the end of it',
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 11),
        expected: '> hello world',
        cursor: 13,
      ),
      (
        name: 'prefixes only the cursor line of a multiline message',
        text: 'one\ntwo three\nfour',
        selection: TextSelection.collapsed(offset: 8),
        expected: 'one\n> two three\nfour',
        cursor: 10,
      ),
      (
        name: 'prefixes an empty line when the cursor is right after a newline',
        text: 'one\n',
        selection: TextSelection.collapsed(offset: 4),
        expected: 'one\n> ',
        cursor: 6,
      ),
      (
        name: 'prefixes the first line when the cursor is at the very start',
        text: 'hello',
        selection: TextSelection.collapsed(offset: 0),
        expected: '> hello',
        cursor: 2,
      ),
      (
        name: 'inserts a quote prefix into an empty composer',
        text: '',
        selection: null,
        expected: '> ',
        cursor: null,
      ),
    ];

    for (final example in cases) {
      testWidgets(example.name, (tester) async {
        await tester.pumpWidget(buildComposerUnderTest());
        await typeAndSelect(tester, example.text, selection: example.selection);

        await tester.tap(find.byTooltip('Block quote'));
        await tester.pump();

        final controller = composerController(tester);
        expect(controller.text, example.expected);
        expect(
          controller.selection,
          TextSelection.collapsed(
            offset: example.cursor ?? example.expected.length,
          ),
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
      });
    }
  });

  group('DmMessageComposer Divider button', () {
    composerTest('inserts a divider into an empty composer', (
      tester,
      field,
    ) async {
      await tapDivider(tester);

      expect(field.controller!.text, '---\n');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 4),
      );
    });

    composerTest(
      'puts a blank line before the divider so it is not read as a heading',
      (tester, field) async {
        await typeAndPlaceCursorAtEnd(tester, field, 'hello');

        await tapDivider(tester);

        expect(field.controller!.text, 'hello\n\n---\n');
        expect(
          field.controller!.selection,
          const TextSelection.collapsed(offset: 'hello\n\n---\n'.length),
        );
      },
    );

    composerTest('adds only one newline when the text already ends with one', (
      tester,
      field,
    ) async {
      await typeAndPlaceCursorAtEnd(tester, field, 'hello\n');

      await tapDivider(tester);

      expect(field.controller!.text, 'hello\n\n---\n');
    });

    composerTest('inserts after the selection without removing it', (
      tester,
      field,
    ) async {
      await tester.enterText(find.byType(TextField), 'hello world');
      field.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pump();

      await tapDivider(tester);

      expect(field.controller!.text, 'hello\n\n---\n world');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 'hello\n\n---\n'.length),
      );
    });
  });

  group('DmMessageComposer formatting shortcuts', () {
    testWidgets('Ctrl+B wraps the selected text in bold markers', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(tester, 'hello');

      await pressShortcut(tester, LogicalKeyboardKey.keyB);

      expect(composerController(tester).text, '**hello**');
    });

    testWidgets('Ctrl+I wraps the selected text in italic markers', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(tester, 'hello');

      await pressShortcut(tester, LogicalKeyboardKey.keyI);

      expect(composerController(tester).text, '*hello*');
    });

    testWidgets('Cmd+B works the same as Ctrl+B', (tester) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(tester, 'hello');

      await pressShortcut(
        tester,
        LogicalKeyboardKey.keyB,
        modifier: LogicalKeyboardKey.metaLeft,
      );

      expect(composerController(tester).text, '**hello**');
    });

    testWidgets('with no selection, inserts markers with cursor between', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(
        tester,
        'hi ',
        selection: const TextSelection.collapsed(offset: 3),
      );

      await pressShortcut(tester, LogicalKeyboardKey.keyB);

      final controller = composerController(tester);
      expect(controller.text, 'hi ****');
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
    });
  });

  group('DmMessageComposer turning a format off', () {
    /// Types [typed] at the caret, as the keyboard would.
    Future<void> typeAtCaret(WidgetTester tester, String typed) async {
      final controller = composerController(tester);
      final caret = controller.selection.start;
      final text = controller.text;
      controller.value = TextEditingValue(
        text: text.substring(0, caret) + typed + text.substring(caret),
        selection: TextSelection.collapsed(offset: caret + typed.length),
      );
      await tester.pump();
    }

    Future<void> tapFormat(WidgetTester tester, String tooltip) async {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
    }

    const formats = [
      (tooltip: 'Bold (Ctrl+B)', marker: '**'),
      (tooltip: 'Italic (Ctrl+I)', marker: '*'),
      (tooltip: 'Strikethrough', marker: '~~'),
      (tooltip: 'Inline code', marker: '`'),
    ];

    for (final format in formats) {
      final m = format.marker;

      testWidgets('${format.tooltip}: a second click ends the run', (
        tester,
      ) async {
        await tester.pumpWidget(buildComposerUnderTest());
        await typeAndSelect(
          tester,
          '',
          selection: const TextSelection.collapsed(offset: 0),
        );

        await tapFormat(tester, format.tooltip);
        await typeAtCaret(tester, 'word');
        await tapFormat(tester, format.tooltip);
        await typeAtCaret(tester, ' plain');

        final controller = composerController(tester);
        expect(controller.text, '${m}word$m plain');
        expect(
          controller.selection,
          TextSelection.collapsed(offset: '${m}word$m plain'.length),
        );
        controller.clear();
        await tester.pump(const Duration(milliseconds: 300));
      });

      testWidgets('${format.tooltip}: two clicks in a row leave no markers', (
        tester,
      ) async {
        await tester.pumpWidget(buildComposerUnderTest());
        await typeAndSelect(
          tester,
          'hi ',
          selection: const TextSelection.collapsed(offset: 3),
        );

        await tapFormat(tester, format.tooltip);
        await tapFormat(tester, format.tooltip);

        final controller = composerController(tester);
        expect(controller.text, 'hi ');
        expect(controller.selection, const TextSelection.collapsed(offset: 3));
        controller.clear();
        await tester.pump(const Duration(milliseconds: 300));
      });
    }

    testWidgets('closes a run that has no closing marker yet', (tester) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(
        tester,
        '**bold',
        selection: const TextSelection.collapsed(offset: 6),
      );

      await tapFormat(tester, 'Bold (Ctrl+B)');
      await typeAtCaret(tester, ' plain');

      final controller = composerController(tester);
      expect(controller.text, '**bold** plain');
      controller.clear();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('Italic inside a bold run still starts an italic pair', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(
        tester,
        '**bold**',
        selection: const TextSelection.collapsed(offset: 6),
      );

      await tapFormat(tester, 'Italic (Ctrl+I)');

      final controller = composerController(tester);
      expect(controller.text, '**bold****');
      expect(controller.selection, const TextSelection.collapsed(offset: 7));
      controller.clear();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('Ctrl+B also ends the bold run', (tester) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(
        tester,
        '**bold**',
        selection: const TextSelection.collapsed(offset: 6),
      );

      await pressShortcut(tester, LogicalKeyboardKey.keyB);

      final controller = composerController(tester);
      expect(controller.text, '**bold**');
      expect(controller.selection, const TextSelection.collapsed(offset: 8));
      controller.clear();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('DmMessageComposer toolbar on a composer that was never focused', () {
    composerTest('Bold inserts its markers with the cursor between', (
      tester,
      field,
    ) async {
      expect(field.controller!.selection.isValid, isFalse);

      await tester.tap(find.byTooltip('Bold (Ctrl+B)'));
      await tester.pump();

      expect(field.controller!.text, '****');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 2),
      );
    });

    composerTest('Link inserts the link stub with the cursor in the label', (
      tester,
      field,
    ) async {
      await tester.tap(find.byTooltip('Link'));
      await tester.pump();

      expect(field.controller!.text, '[](url)');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 1),
      );
    });

    composerTest('Block quote starts a quote line', (tester, field) async {
      await tester.tap(find.byTooltip('Block quote'));
      await tester.pump();

      expect(field.controller!.text, '> ');
    });

    composerTest('Italic focuses the field so typing continues there', (
      tester,
      field,
    ) async {
      await tester.tap(find.byTooltip('Italic (Ctrl+I)'));
      await tester.pump();

      expect(field.controller!.text, '**');
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    composerTest('appends after draft text instead of doing nothing', (
      tester,
      field,
    ) async {
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      await tester.tap(find.byTooltip('Inline code'));
      await tester.pump();

      expect(field.controller!.text, 'hello``');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 6),
      );
    });

    composerTest('still wraps exactly the selected range', (
      tester,
      field,
    ) async {
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'hello');
      field.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Strikethrough'));
      await tester.pump();

      expect(field.controller!.text, '~~hello~~');
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 2, extentOffset: 7),
      );
    });
  });

  group('DmMessageComposer drafts with no channel yet', () {
    testWidgets('each person keeps their own draft', (tester) async {
      final draftKey = ValueNotifier('new-dm:ada');
      addTearDown(draftKey.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(
                FakeSecureStorageService(),
                userId: 'user-1',
                orgId: 'org-1',
              ),
            ),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: ValueListenableBuilder<String>(
                valueListenable: draftKey,
                builder: (context, key, _) => DmMessageComposer(
                  recipientName: 'Ada',
                  channelId: '',
                  draftKey: key,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'for ada only');
      await tester.pump(const Duration(milliseconds: 300));

      draftKey.value = 'new-dm:grace';
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(composerController(tester).text, isEmpty);

      draftKey.value = 'new-dm:ada';
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(composerController(tester).text, 'for ada only');

      composerController(tester).clear();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('DmMessageComposer voice notes', () {
    testWidgets('enables send when a voice note is recorded without text', (
      tester,
    ) async {
      final recorder = _FakeAudioRecorder();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(
                FakeSecureStorageService(),
                userId: 'user-1',
                orgId: 'org-1',
              ),
            ),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: DmMessageComposer(
                recipientName: 'Ada',
                channelId: 'dm-1',
                audioRecorder: recorder,
              ),
            ),
          ),
        ),
      );

      Icon sendIcon() => tester.widget<Icon>(find.byIcon(Icons.send_rounded));

      expect(
        sendIcon().color,
        AppPalette.light.textHint.withValues(alpha: 0.55),
      );

      await tester.tap(find.byTooltip('More actions'));
      await tester.pump();
      await tester.tap(find.byTooltip('Voice message'));
      await tester.pump();
      await tester.tap(find.byTooltip('Stop recording').first);
      await tester.pump();

      expect(recorder.recordedPaths, hasLength(1));
      expect(sendIcon().color, AppPalette.light.primary);
    });

    testWidgets('tapping formatting help button opens FormattingHelpDialog', (
      tester,
    ) async {
      await pumpComposer(tester);

      expect(
        find.byKey(const Key('dm_composer_formatting_help_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('dm_composer_formatting_help_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FormattingHelpDialog), findsOneWidget);
      expect(find.text('Formatting help'), findsOneWidget);
    });
  });

  group('editor height cap (#222)', () {
    double fieldHeight(WidgetTester tester) =>
        tester.getSize(find.byType(TextField)).height;

    testWidgets('a short draft keeps the compact single-line height', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      final emptyHeight = fieldHeight(tester);

      await tester.enterText(find.byType(TextField), 'Hi Ada');
      await tester.pump();

      expect(fieldHeight(tester), emptyHeight);
    });

    testWidgets('a long draft stops growing at eight lines and scrolls', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      final shortHeight = fieldHeight(tester);
      final draft = List.generate(40, (i) => 'Line ${i + 1}').join('\n');

      await tester.enterText(find.byType(TextField), draft);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 8);
      final cappedHeight = fieldHeight(tester);
      expect(cappedHeight, greaterThan(shortHeight));
      expect(cappedHeight, lessThan(200));
      expect(composerController(tester).text, draft);

      final internalScroll = find.descendant(
        of: find.byType(EditableText),
        matching: find.byType(Scrollable),
      );
      expect(internalScroll, findsOneWidget);
      expect(
        tester.state<ScrollableState>(internalScroll).position.maxScrollExtent,
        greaterThan(0),
      );
    });

    testWidgets('a long draft still leaves the Send control on screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1100, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildComposerUnderTest());
      await tester.enterText(
        find.byType(TextField),
        List.generate(40, (i) => 'Line ${i + 1}').join('\n'),
      );
      await tester.pump();

      final composerBottom = tester
          .getRect(find.byType(DmMessageComposer))
          .bottom;
      expect(composerBottom, lessThan(500));
      expect(
        tester.getRect(find.byIcon(Icons.send_rounded)).bottom,
        lessThanOrEqualTo(composerBottom),
      );
    });
  });
}

class _FakeAudioRecorder extends Fake implements AudioRecorder {
  final recordedPaths = <String>[];

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    recordedPaths.add(path);
  }

  @override
  Future<String?> stop() async =>
      recordedPaths.isEmpty ? null : recordedPaths.last;

  @override
  Future<void> dispose() async {}
}
