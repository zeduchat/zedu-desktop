import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

class MockDraftStore extends Mock implements DmDraftStore {}

// Avoids the GetIt/locator setup the real AuthNotifier needs.
class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

void main() {
  testWidgets('shows an error with Retry when the history fails to load', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MockDmRepository();
    var fail = true;
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async {
      if (fail) throw Exception('network error');
      return [
        {'id': 'm1', 'content': 'Hello there', 'user_id': 'user-1'},
      ];
    });
    final drafts = MockDraftStore();
    when(() => drafts.load(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(FakeAuthNotifier.new),
          dmRepositoryProvider.overrideWithValue(repository),
          dmDraftStoreProvider.overrideWith((ref) => drafts),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: DmChatArea(
              conversation: DmConversation(
                channelId: 'chat-1',
                username: 'History Tester',
                participantId: 'user-1',
                previewMessage: '',
                unreadCount: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load messages."), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);

    fail = false;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load messages."), findsNothing);
    expect(find.text('Hello there', findRichText: true), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
