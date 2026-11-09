import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

class MockDraftStore extends Mock implements DmDraftStore {}

// The message bubble now hosts the Later bookmark button, which reads the
// selected workspace. Without a registered AppConfig the real notifier would
// kick off fetchWorkspaces through GetIt, so tests supply an empty one.
class FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();
}

// Avoids the GetIt/locator setup the real AuthNotifier needs.
class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

void main() {
  // The widgets reach the auth and workspace providers, which read AppConfig.
  setUp(() {
    if (locator.isRegistered<AppConfig>()) locator.unregister<AppConfig>();
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
    );
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) locator.unregister<AppConfig>();
  });

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
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
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
