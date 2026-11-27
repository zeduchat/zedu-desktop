import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  // The composer creates a real AudioRecorder, whose plugin has no
  // implementation in tests. The test runs under runAsync, so the recorder's
  // MissingPluginException could land inside it depending on timing, which
  // made it fail at random on CI. Answer the channel as the other composer
  // tests do.
  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  testWidgets('an unreadable file is rejected and the readable ones are kept', (
    tester,
  ) async {
    final storage = _MockSecureStorageService();
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    final key = GlobalKey<DmMessageComposerState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          dmDraftStoreProvider.overrideWith(
            (ref) => DmDraftStore(storage, userId: 'u', orgId: 'o'),
          ),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: DmMessageComposer(
              key: key,
              recipientName: 'Ada',
              channelId: 'channel-1',
              participants: [
                DmParticipant(
                  userId: 'user-1',
                  username: 'ada_test',
                  email: 'ada@example.com',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final dir = Directory.systemTemp.createTempSync('composer_files_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final readable = File('${dir.path}/notes.txt')..writeAsStringSync('hi');

    await tester.runAsync(
      () => key.currentState!.addFiles([
        XFile(readable.path),
        XFile('${dir.path}/missing.txt'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    // The unreadable file is rejected: it appears only in the message, never
    // as a pending attachment.
    expect(find.textContaining('missing.txt'), findsOneWidget);
    expect(find.textContaining('notes.txt'), findsOneWidget);
  });
}
