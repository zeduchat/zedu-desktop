import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class FakeSignedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'test-org',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

class MockDmRepository extends Mock implements DmRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  setUp(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
    );
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  testWidgets('a pending deep-link jump scrolls an old message into view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Enough messages that the target (near the end = oldest) is far
    // outside the lazily built range when the chat opens.
    final messages = List.generate(
      200,
      (index) => {
        'id': 'm$index',
        'content': 'message $index',
        'user_id': index.isEven ? 'user-1' : 'u-2',
        'created_at':
            '2026-10-17T08:${(index % 60).toString().padLeft(2, '0')}:00Z',
      },
    );
    final repository = MockDmRepository();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => messages);
    final storage = MockSecureStorageService();
    when(() => storage.readData(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dmRepositoryProvider.overrideWithValue(repository),
          authNotifierProvider.overrideWith(FakeSignedInAuthNotifier.new),
          dmDraftStoreProvider.overrideWith(
            (ref) => DmDraftStore(storage, userId: 'user-1', orgId: 'org-1'),
          ),
          pendingMessageJumpProvider.overrideWith(
            (ref) =>
                const PendingMessageJump(channelId: 'ch-1', messageId: 'm190'),
          ),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: DmChatArea(
              conversation: DmConversation(
                channelId: 'ch-1',
                username: 'Ada Lovelace',
                participantId: 'u-2',
                previewMessage: '',
                unreadCount: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Drive frames so the scroll loop can build and reveal the target.
    final target = find.text('message 190', findRichText: true);
    for (var i = 0; i < 80 && target.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(target, findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DmChatArea)),
    );
    expect(container.read(pendingMessageJumpProvider), isNull);
  });
}
