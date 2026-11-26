import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class VoiceErrorStorage extends Fake implements SecureStorageService {
  @override
  Future<String?> readData(String key) async => null;

  @override
  Future<void> writeData(String key, String value) async {}

  @override
  Future<void> deleteValue(String key) async {}
}

class VoiceErrorHistory extends Mock implements ChatHistoryNotifier {}

/// A recorder whose start and stop both fail, so the composer's catch blocks
/// are the ones under test.
class FailingRecorder extends Fake implements RecordPlatform {
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
  }) async => throw PlatformException(
    code: 'permission-denied',
    message: 'microphone is busy',
  );

  @override
  Future<String?> stop(String recorderId) async =>
      throw PlatformException(code: 'audio-hardware-error');

  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
}

void main() {
  late RecordPlatform originalRecorder;
  late GlobalKey<DmMessageComposerState> composerKey;
  late VoiceErrorHistory history;

  setUp(() {
    originalRecorder = RecordPlatform.instance;
    RecordPlatform.instance = FailingRecorder();
    composerKey = GlobalKey<DmMessageComposerState>();
    history = VoiceErrorHistory();
    when(
      () => history.sendMessage(any(), media: any(named: 'media')),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    RecordPlatform.instance = originalRecorder;
    appRecordedPaths.clear();
  });

  testWidgets('a failed recording shows a clean message, not the exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dmDraftStoreProvider.overrideWith(
            (ref) => DmDraftStore(
              VoiceErrorStorage(),
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

    await tester.tap(find.byTooltip('More actions'));
    await tester.pump();
    await tester.tap(find.byTooltip('Voice message'));
    await tester.pumpAndSettle();

    expect(find.text('Recording...'), findsNothing);
    expect(
      find.text(
        'Could not start recording. Check your microphone and try again.',
      ),
      findsOneWidget,
    );
    // The platform error must not reach the person.
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(find.textContaining('permission-denied'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
