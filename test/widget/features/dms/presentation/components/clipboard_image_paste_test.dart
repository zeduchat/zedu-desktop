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

class FakeDataReader extends Fake implements DataReader {
  final Map<FileFormat, Uint8List> formats;
  final Uri? fileUri;

  FakeDataReader({this.formats = const {}, this.fileUri});

  @override
  bool canProvide(DataFormat format) {
    if ((format as dynamic) == Formats.fileUri && fileUri != null) return true;
    return formats.containsKey(format);
  }

  @override
  ReadProgress? getFile(
    FileFormat? format,
    void Function(DataReaderFile file) onFile, {
    void Function(Object error)? onError,
    bool allowVirtualFiles = true,
    bool synthesizeFilesFromURIs = true,
  }) {
    if (format != null) {
      final bytes = formats[format];
      if (bytes != null) {
        onFile(FakeDataReaderFile(bytes));
      }
    }
    return null;
  }

  @override
  ReadProgress? getValue<T extends Object>(
    ValueFormat<T> format,
    void Function(T? value) onValue, {
    void Function(Object error)? onError,
  }) {
    if ((format as dynamic) == Formats.fileUri && fileUri != null) {
      onValue(fileUri as T);
    } else {
      onValue(null);
    }
    return null;
  }
}

class FakeDataReaderFile extends Fake implements DataReaderFile {
  final Uint8List bytes;
  FakeDataReaderFile(this.bytes);

  @override
  Future<Uint8List> readAll() async => bytes;

  @override
  Stream<Uint8List> getStream() => Stream.value(bytes);
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => null,
        );
  });

  group('Desktop Message Composer Clipboard Image Paste', () {
    testWidgets(
      'DmMessageComposer attaches pasted PNG image from clipboard and shows in AttachmentPreviewBar',
      (tester) async {
        final composerKey = GlobalKey<DmMessageComposerState>();

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
                  key: composerKey,
                  recipientName: 'Ada',
                  channelId: 'dm-1',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AttachmentPreviewBar), findsNothing);

        final dummyPng = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]);
        final reader = FakeDataReader(formats: {Formats.png: dummyPng});

        final handled = await tester.runAsync(
          () => composerKey.currentState!.handlePaste(reader: reader),
        );
        expect(handled, isTrue);

        await tester.pumpAndSettle();

        expect(find.byType(AttachmentPreviewBar), findsOneWidget);
        expect(find.textContaining('pasted_image_'), findsOneWidget);
      },
    );

    testWidgets('DmMessageComposer attaches pasted JPEG image from clipboard', (
      tester,
    ) async {
      final composerKey = GlobalKey<DmMessageComposerState>();

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
                key: composerKey,
                recipientName: 'Ada',
                channelId: 'dm-2',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dummyJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      final reader = FakeDataReader(formats: {Formats.jpeg: dummyJpeg});

      final handled = await tester.runAsync(
        () => composerKey.currentState!.handlePaste(reader: reader),
      );
      expect(handled, isTrue);

      await tester.pumpAndSettle();

      expect(find.byType(AttachmentPreviewBar), findsOneWidget);
      expect(find.textContaining('.jpg'), findsOneWidget);
    });

    testWidgets(
      'MessageComposer attaches pasted image and displays attachment Chip',
      (tester) async {
        final composerKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileNotifierProvider.overrideWith(
                _FakeUserProfileNotifier.new,
              ),
            ],
            child: buildTestMaterialApp(
              Scaffold(
                body: MessageComposer(
                  key: composerKey,
                  activeChat: const ActiveChatState(
                    id: 'general',
                    type: ActiveChatType.channel,
                  ),
                  onSend: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dummyPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        final reader = FakeDataReader(formats: {Formats.png: dummyPng});

        final dynamic state = tester.state(find.byType(MessageComposer));
        final handled = await tester.runAsync(
          () => state.handlePaste(reader: reader) as Future<bool>,
        );
        expect(handled, isTrue);

        await tester.pumpAndSettle();

        expect(find.byType(Chip), findsOneWidget);
        expect(find.textContaining('pasted_image_'), findsOneWidget);
      },
    );
  });
}
