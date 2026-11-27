import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class _SignedOutAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

final _lastReadAt = DateTime.utc(2026, 10, 17, 8);

/// Unread message [k] (0 is the oldest) arrived [k] minutes after 09:00.
Map<String, dynamic> _unread(int k) => {
  'id': 'unread-$k',
  'content': 'unread $k',
  'user_id': 'u-2',
  'created_at': DateTime.utc(2026, 10, 17, 9, k).toIso8601String(),
};

Map<String, dynamic> _read(int k) => {
  'id': 'read-$k',
  'content': 'read $k',
  'user_id': 'u-2',
  'created_at': DateTime.utc(2026, 10, 17, 7, 59 - k).toIso8601String(),
};

/// #2680: a DM opened with 10 or more unread messages offers "Jump to first
/// unread", which loads back to the oldest unread message and shows it.
void main() {
  Future<MockDmRepository> pumpChat(
    WidgetTester tester, {
    required int unreadCount,
    required Map<int, List<Map<String, dynamic>>> pages,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MockDmRepository();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((call) async => pages[call.namedArguments[#page]] ?? []);
    final storage = MockSecureStorageService();
    when(() => storage.readData(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedOutAuth.new),
          dmRepositoryProvider.overrideWithValue(repository),
          dmDraftStoreProvider.overrideWith(
            (ref) => DmDraftStore(storage, userId: 'u', orgId: 'o'),
          ),
          savedMessagesProvider.overrideWith((ref) async => []),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: DmChatArea(
              conversation: DmConversation(
                channelId: 'ch-1',
                username: 'Ada Lovelace',
                participantId: 'u-2',
                previewMessage: '',
                unreadCount: unreadCount,
                lastReadAt: _lastReadAt,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('jumps to the first unread message on an older page', (
    tester,
  ) async {
    // Newest first: page 1 holds unread 24..5, page 2 unread 4..0 then
    // messages read before last_read_at.
    final repository = await pumpChat(
      tester,
      unreadCount: 25,
      pages: {
        1: [for (var k = 24; k >= 5; k--) _unread(k)],
        2: [
          for (var k = 4; k >= 0; k--) _unread(k),
          for (var k = 0; k < 3; k++) _read(k),
        ],
      },
    );

    expect(find.text('Jump to first unread'), findsOneWidget);
    expect(
      find.text('unread 0', findRichText: true).hitTestable(),
      findsNothing,
    );

    await tester.tap(find.text('Jump to first unread'));
    await tester.pumpAndSettle();

    verify(() => repository.getMessages('ch-1', page: 2)).called(1);
    expect(
      find.text('unread 0', findRichText: true).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Jump to first unread'), findsNothing);

    // Let the highlight timer finish.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a conversation with a few unread messages offers no jump', (
    tester,
  ) async {
    await pumpChat(
      tester,
      unreadCount: 2,
      pages: {
        1: [_unread(1), _unread(0), _read(0)],
      },
    );

    expect(find.text('Jump to first unread'), findsNothing);
  });

  testWidgets('the jump button can be dismissed', (tester) async {
    await pumpChat(
      tester,
      unreadCount: 12,
      pages: {
        1: [for (var k = 11; k >= 0; k--) _unread(k), _read(0)],
      },
    );

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('Jump to first unread'), findsNothing);
  });
}
