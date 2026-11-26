import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/presentation/components/composer/attachment_preview_bar.dart';
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

const _filePickerChannel = MethodChannel(
  'miguelruivo.flutter.plugins.filepicker',
);

/// [path] as macOS and Linux write it: rooted at '/', with '/' separators.
/// On Windows the drive letter is dropped, which still names the same file
/// on the current drive.
String posixStyle(String path) {
  if (!Platform.isWindows) return path;
  return path.replaceFirst(RegExp(r'^[A-Za-z]:'), '').replaceAll(r'\', '/');
}

/// Makes the system file dialog return [paths].
void fakeFilePicker(WidgetTester tester, List<String> paths) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    _filePickerChannel,
    (call) async => [
      for (final path in paths)
        {'path': path, 'name': path.split('/').last, 'size': 4},
    ],
  );
  addTearDown(
    () => messenger.setMockMethodCallHandler(_filePickerChannel, null),
  );
}

Future<void> pumpComposer(WidgetTester tester) async {
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
  await tester.pumpAndSettle();
}

/// Opens the More actions menu, taps Attach file and lets the composer check
/// the picked files on disk, which needs real time.
Future<void> attachFiles(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More actions'));
  await tester.pump();
  await tester.runAsync(() async {
    await tester.tap(find.byTooltip('Attach file'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;
  late String reportPath;
  late String notesPath;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => null,
        );
    tempDir = Directory.systemTemp.createTempSync('zedu_attach_test');
    final report = File('${tempDir.path}${Platform.pathSeparator}report.pdf')
      ..writeAsBytesSync([1, 2, 3, 4]);
    final notes = File('${tempDir.path}${Platform.pathSeparator}notes..v2.txt')
      ..writeAsBytesSync([1, 2, 3, 4]);
    reportPath = posixStyle(report.path);
    notesPath = posixStyle(notes.path);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  group('DmMessageComposer Attach file', () {
    testWidgets('attaches files picked from absolute macOS and Linux paths', (
      tester,
    ) async {
      expect(reportPath, startsWith('/'));
      fakeFilePicker(tester, [reportPath, notesPath]);
      await pumpComposer(tester);

      await attachFiles(tester);

      final files = tester
          .widget<AttachmentPreviewBar>(find.byType(AttachmentPreviewBar))
          .files;
      expect(files.map((f) => f.path), [reportPath, notesPath]);
      expect(find.textContaining('report.pdf'), findsOneWidget);
      expect(find.textContaining('notes..v2.txt'), findsOneWidget);
      expect(find.textContaining('Invalid file path'), findsNothing);
    });

    testWidgets('does not use the bare extension as the MIME type', (
      tester,
    ) async {
      fakeFilePicker(tester, [reportPath]);
      await pumpComposer(tester);

      await attachFiles(tester);

      final files = tester
          .widget<AttachmentPreviewBar>(find.byType(AttachmentPreviewBar))
          .files;
      expect(files, hasLength(1));
      expect(files.single.mimeType, isNot('pdf'));
    });
  });
}
