import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _MockChatWebsocketService extends Mock implements ChatWebsocketService {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  final List<TeamMember> _members;
  _FakeUserProfileNotifier(this._members);

  @override
  UserProfileState build() =>
      UserProfileState(isLoading: false, teamMembers: _members);
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();
}

class _OnlineNetworkStatusNotifier extends NetworkStatusNotifier {
  @override
  NetworkStatus build() => NetworkStatus.online;
}

TeamMember _member(String id, String name) => TeamMember(
  id: id,
  email: '${name.toLowerCase()}@zedu.chat',
  role: 'member',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
  name: name,
);

void main() {
  final alice = _member('u1', 'Alice');
  final bob = _member('u2', 'Bob');

  late _MockChatWebsocketService ws;
  late StreamController<ChatWebsocketMessage> wsController;

  setUp(() {
    ws = _MockChatWebsocketService();
    wsController = StreamController<ChatWebsocketMessage>.broadcast();
    when(() => ws.messageStream).thenAnswer((_) => wsController.stream);
    when(() => ws.connect(any())).thenReturn(null);
  });

  tearDown(() => wsController.close());

  Future<ProviderContainer> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        userProfileNotifierProvider.overrideWith(
          () => _FakeUserProfileNotifier([alice, bob]),
        ),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        chatWebsocketProvider.overrideWithValue(ws),
        networkStatusProvider.overrideWith(_OnlineNetworkStatusNotifier.new),
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestMaterialApp(const Scaffold(body: NewGroupChatView())),
      ),
    );
    return container;
  }

  Future<void> selectAliceAndBobAndCreate(WidgetTester tester) async {
    for (final email in ['alice@zedu.chat', 'bob@zedu.chat']) {
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.tap(find.text(email));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    // createGroupDm waits 800 ms to imitate a request.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('creating a brand-new group says it was created', (tester) async {
    final container = await pumpView(tester);

    await selectAliceAndBobAndCreate(tester);

    expect(
      find.text('Group DM "Alice, Bob" created successfully!'),
      findsOneWidget,
    );
    expect(find.textContaining('Opening existing conversation'), findsNothing);
    expect(container.read(groupDmProvider), hasLength(1));
  });

  testWidgets('creating a group that already exists says it is opening it', (
    tester,
  ) async {
    final container = await pumpView(tester);
    final pending = container.read(groupDmProvider.notifier).createGroupDm([
      alice,
      bob,
    ]);
    await tester.pump(const Duration(seconds: 1));
    expect(await pending, isA<Success<GroupDM>>());

    await selectAliceAndBobAndCreate(tester);

    expect(
      find.text('Opening existing conversation with Alice, Bob...'),
      findsOneWidget,
    );
    expect(find.textContaining('created successfully'), findsNothing);
    expect(container.read(groupDmProvider), hasLength(1));
  });
}
