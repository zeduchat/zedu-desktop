import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

const _recordChannel = MethodChannel('com.llfbandit.record/messages');

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

Future<void> _pumpComposer(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileNotifierProvider.overrideWith(_FakeUserProfileNotifier.new),
      ],
      child: buildTestMaterialApp(
        Scaffold(
          body: MessageComposer(
            activeChat: ActiveChatState.generalChannel,
            onSend: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_recordChannel, (call) async {
          return call.method == 'hasPermission' ? true : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_recordChannel, null);
  });

  testWidgets('the send button has a tooltip once there is text', (
    tester,
  ) async {
    await _pumpComposer(tester);

    // The formatting bar shows on focus, and its buttons insert text, which
    // swaps the mic for the send icon.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.byTooltip('Bold'));
    await tester.pumpAndSettle();

    final sendButton = find.ancestor(
      of: find.byIcon(Icons.send),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(sendButton).tooltip, 'Send message');
  });

  testWidgets('the stop button has a tooltip while recording', (tester) async {
    await _pumpComposer(tester);

    await tester.tap(find.byTooltip('Record voice note'));
    await tester.pumpAndSettle();

    final stopButton = find.ancestor(
      of: find.byIcon(Icons.stop_circle),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(stopButton).tooltip, 'Stop recording');
  });
}
