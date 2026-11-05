import 'dart:io';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class SendIconStorage extends Fake implements SecureStorageService {
  @override
  Future<String?> readData(String key) async => null;

  @override
  Future<void> writeData(String key, String value) async {}

  @override
  Future<void> deleteValue(String key) async {}
}

class SendIconHistory extends Mock implements ChatHistoryNotifier {}

class SendIconRecorder extends Fake implements RecordPlatform {
  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      true;

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async {}

  @override
  Future<String?> stop(String recorderId) async => 'test-voice.m4a';

  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
}

void main() {
  late RecordPlatform originalRecorder;
  late GlobalKey<DmMessageComposerState> composerKey;
  late SendIconHistory history;

  setUp(() {
    originalRecorder = RecordPlatform.instance;
    RecordPlatform.instance = SendIconRecorder();
    composerKey = GlobalKey<DmMessageComposerState>();
    history = SendIconHistory();
    when(
      () => history.sendMessage(any(), media: any(named: 'media')),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    RecordPlatform.instance = originalRecorder;
    // The fake recorder creates no files at the paths the composer reserves.
    appRecordedPaths.clear();
  });

  TextEditingController controller(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!;

  void expectActive(WidgetTester tester, bool active) {
    final colors = tester.element(find.byType(DmMessageComposer)).colors;
    expect(
      tester.widget<Icon>(find.byIcon(Icons.send_rounded)).color,
      active ? colors.primary : colors.textHint.withValues(alpha: 0.55),
    );
  }

  Future<void> attachFile(WidgetTester tester) async {
    // addFiles checks the file on disk, which needs real async in a widget test.
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('send_icon_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}${Platform.pathSeparator}sample.txt');
      await file.writeAsBytes([1, 2, 3]);
      await composerKey.currentState!.addFiles([
        XFile(file.path, mimeType: 'text/plain'),
      ]);
    });
    await tester.pump();
  }

  void composerTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(
                SendIconStorage(),
                userId: 'user-1',
                orgId: 'org-1',
              ),
            ),
            chatHistoryProvider('dm-1').overrideWith((ref) => history),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: DmMessageComposer(
                key: composerKey,
                recipientName: 'Test User',
                channelId: 'dm-1',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      try {
        await body(tester);
      } finally {
        controller(tester).clear();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  }

  composerTest('empty and whitespace-only drafts keep the icon inactive', (
    tester,
  ) async {
    expectActive(tester, false);
    await tester.enterText(find.byType(TextField), '   \n');
    await tester.pump();
    expectActive(tester, false);
  });

  composerTest('text activates the icon and clearing it resets the icon', (
    tester,
  ) async {
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expectActive(tester, true);
    controller(tester).clear();
    await tester.pump();
    expectActive(tester, false);
  });

  composerTest('file-only draft activates the icon until the file is removed', (
    tester,
  ) async {
    await attachFile(tester);
    expect(find.text('sample.txt'), findsOneWidget);
    expectActive(tester, true);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expectActive(tester, false);
  });

  composerTest('a file keeps the icon active after text becomes whitespace', (
    tester,
  ) async {
    await attachFile(tester);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expectActive(tester, true);
  });

  composerTest('file-only send still uses the existing send flow and resets', (
    tester,
  ) async {
    await attachFile(tester);
    expectActive(tester, true);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    final files =
        verify(
              () => history.sendMessage('', media: captureAny(named: 'media')),
            ).captured.single
            as List<XFile>;
    expect(files.single.name, 'sample.txt');
    expect(find.text('sample.txt'), findsNothing);
    expectActive(tester, false);
  });

  composerTest('completed voice note activates the icon until removed', (
    tester,
  ) async {
    await tester.tap(find.byTooltip('Voice message'));
    await tester.pumpAndSettle();
    expect(find.text('Recording...'), findsOneWidget);
    expectActive(tester, false);
    await tester.tap(find.byTooltip('Stop recording').first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    expectActive(tester, true);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expectActive(tester, false);
  });

  composerTest('attachments do not activate an empty edit', (tester) async {
    await attachFile(tester);
    composerKey.currentState!.enterEditMode('message-1', 'original');
    await tester.pump();
    expectActive(tester, true);
    controller(tester).clear();
    await tester.pump();
    expectActive(tester, false);
  });
}
