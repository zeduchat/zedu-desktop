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
  WorkspaceState build() => const WorkspaceState();
}

class _FakeDmListNotifier extends DmListNotifier {
  _FakeDmListNotifier(this._conversations);

  final List<DmConversation> _conversations;

  @override
  Future<List<DmConversation>> build() async => _conversations;
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
  List<DmConversation> conversations,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        dmDraftStoreProvider.overrideWith(
          (ref) => DmDraftStore(
            _FakeSecureStorageService(),
            userId: 'user-1',
            orgId: 'org-1',
          ),
        ),
        dmListProvider.overrideWith(() => _FakeDmListNotifier(conversations)),
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
}
