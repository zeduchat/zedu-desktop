import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _FakeSecureStorageService extends Fake implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> readData(String key) async => _values[key];

  @override
  Future<void> writeData(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Org 1', avatar: ''),
  );
}

class _FakeSignedInAuthNotifier extends AuthNotifier {
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

class _FakeDmListNotifier extends DmListNotifier {
  _FakeDmListNotifier(this._conversations);

  final List<DmConversation> _conversations;

  @override
  Future<List<DmConversation>> build() async => _conversations;
}

class _FakeDmRepository extends Fake implements DmRepository {
  _FakeDmRepository(this.conversations);
  final List<DmConversation> conversations;

  @override
  Future<List<DmConversation>> getConversations({
    required String orgId,
    int page = 1,
    bool recentDm = false,
    String? search,
  }) async {
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      return conversations
          .where((c) => c.displayName.toLowerCase().contains(q))
          .toList();
    }
    return conversations;
  }
}

DmConversation _conversation(String channelId, String username) {
  return DmConversation(
    channelId: channelId,
    username: username,
    participantId: 'user-$channelId',
    previewMessage: '',
    unreadCount: 0,
  );
}

Future<void> _pumpSidebar(
  WidgetTester tester,
  List<DmConversation> conversations, {
  DmRepository? repository,
}) async {
  final repo = repository ?? _FakeDmRepository(conversations);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_FakeSignedInAuthNotifier.new),
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        dmDraftStoreProvider.overrideWith(
          (ref) => DmDraftStore(
            _FakeSecureStorageService(),
            userId: 'user-1',
            orgId: 'org-1',
          ),
        ),
        dmListProvider.overrideWith(() => _FakeDmListNotifier(conversations)),
        dmRepositoryProvider.overrideWithValue(repo),
      ],
      child: buildTestMaterialApp(const Scaffold(body: DmSidebarList())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final conversations = [
    _conversation('channel-1', 'Ada Okafor'),
    _conversation('channel-2', 'Bola Ige'),
    _conversation('channel-3', 'Chidi Ada'),
  ];
  final search = find.byType(TextField);

  testWidgets('the search box takes focus and accepts typing', (tester) async {
    await _pumpSidebar(tester, conversations);

    expect(find.text('Find a Conversation'), findsOneWidget);
    await tester.tap(search);
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(of: search, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasPrimaryFocus, isTrue);

    await tester.enterText(search, 'bola');
    await tester.pump();
    expect(find.text('bola'), findsOneWidget);
  });

  testWidgets('filters by name, ignoring case and surrounding spaces', (
    tester,
  ) async {
    await _pumpSidebar(tester, conversations);

    await tester.enterText(search, '  ADA ');
    await tester.pumpAndSettle();

    expect(find.byType(DmListTile), findsNWidgets(2));
    expect(find.text('Ada Okafor'), findsOneWidget);
    expect(find.text('Chidi Ada'), findsOneWidget);
    expect(find.text('Bola Ige'), findsNothing);
  });

  testWidgets('shows a message when nothing matches', (tester) async {
    await _pumpSidebar(tester, conversations);

    await tester.enterText(search, 'zainab');
    await tester.pumpAndSettle();

    expect(find.byType(DmListTile), findsNothing);
    expect(find.text('No conversations match'), findsOneWidget);
    expect(find.text('No recent chats'), findsNothing);
  });

  testWidgets('whitespace-only text keeps the full list', (tester) async {
    await _pumpSidebar(tester, conversations);

    await tester.enterText(search, '   ');
    await tester.pumpAndSettle();

    expect(find.byType(DmListTile), findsNWidgets(3));
  });

  testWidgets('clearing the text restores the full list', (tester) async {
    await _pumpSidebar(tester, conversations);

    await tester.enterText(search, 'zainab');
    await tester.pumpAndSettle();
    expect(find.byType(DmListTile), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byType(DmListTile), findsNWidgets(3));
    expect(find.byTooltip('Clear search'), findsNothing);
    expect(find.text('Find a Conversation'), findsOneWidget);

    await tester.enterText(search, 'bola');
    await tester.pumpAndSettle();
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.byType(DmListTile), findsNWidgets(3));
  });

  testWidgets('an empty organisation still shows "No recent chats"', (
    tester,
  ) async {
    await _pumpSidebar(tester, const []);

    expect(find.text('No recent chats'), findsOneWidget);
  });

  testWidgets('searches server for conversation beyond the first page', (
    tester,
  ) async {
    final page1 = [
      _conversation('channel-1', 'Ada Okafor'),
      _conversation('channel-2', 'Bola Ige'),
    ];
    final allServerConversations = [
      ...page1,
      _conversation('channel-25', 'Zainab Danjuma'),
    ];
    await _pumpSidebar(
      tester,
      page1,
      repository: _FakeDmRepository(allServerConversations),
    );

    expect(find.text('Zainab Danjuma'), findsNothing);

    await tester.enterText(search, 'zainab');
    await tester.pumpAndSettle();

    expect(find.text('Zainab Danjuma'), findsOneWidget);
    expect(find.byType(DmListTile), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('Zainab Danjuma'), findsNothing);
    expect(find.text('Ada Okafor'), findsOneWidget);
    expect(find.text('Bola Ige'), findsOneWidget);
  });

  testWidgets('pins self DM to the top and renders (you) badge', (
    tester,
  ) async {
    final list = [
      _conversation('channel-1', 'Ada Okafor'),
      DmConversation(
        channelId: 'channel-self',
        username: 'Current User',
        participantId: 'user-1',
        previewMessage: '',
        unreadCount: 0,
      ),
      _conversation('channel-2', 'Bola Ige'),
    ];

    await _pumpSidebar(tester, list);

    final tiles = tester
        .widgetList<DmListTile>(find.byType(DmListTile))
        .toList();
    expect(tiles.first.conversation.channelId, 'channel-self');
    expect(find.text('(you)'), findsOneWidget);
    expect(find.text('Current User'), findsOneWidget);
  });

  testWidgets('search query matches self DM by "you"', (tester) async {
    final list = [
      _conversation('channel-1', 'Ada Okafor'),
      DmConversation(
        channelId: 'channel-self',
        username: 'Current User',
        participantId: 'user-1',
        previewMessage: '',
        unreadCount: 0,
      ),
      _conversation('channel-2', 'Bola Ige'),
    ];

    await _pumpSidebar(tester, list);

    await tester.enterText(search, 'you');
    await tester.pumpAndSettle();

    expect(find.byType(DmListTile), findsOneWidget);
    expect(find.text('Current User'), findsOneWidget);
    expect(find.text('(you)'), findsOneWidget);
  });
  });
}
