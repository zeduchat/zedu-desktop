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

  Future<void> pumpChat(
    WidgetTester tester,
    List<Map<String, dynamic>> messages,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
  }

  testWidgets('Copy link copies a deep link to an own message', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpChat(tester, [
      {
        'id': 'm1',
        'content': 'my own message',
        'user_id': 'user-1',
        'created_at': '2026-10-17T08:00:00Z',
      },
    ]);

    await tester.tap(find.byTooltip('Message actions'));
    await tester.pumpAndSettle();

    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Edit message'), findsOneWidget);
    expect(find.text('Delete message'), findsOneWidget);

    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(copied, 'zedu://chat/ch-1?message=m1');
  });

  testWidgets("someone else's message menu only offers Copy link", (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpChat(tester, [
      {
        'id': 'm2',
        'content': 'their message',
        'user_id': 'u-2',
        'created_at': '2026-10-17T08:01:00Z',
      },
    ]);

    // The menu button stays hidden on incoming messages until hovered.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(find.text('their message', findRichText: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Message actions'));
    await tester.pumpAndSettle();

    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Edit message'), findsNothing);
    expect(find.text('Delete message'), findsNothing);

    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(copied, 'zedu://chat/ch-1?message=m2');
  });
}
