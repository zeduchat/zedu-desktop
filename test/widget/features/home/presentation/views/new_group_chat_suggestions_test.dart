import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  _FakeUserProfileNotifier(this._state);
  final UserProfileState _state;

  @override
  UserProfileState build() => _state;
}

class _FakeChannelNotifier extends ChannelNotifier {
  _FakeChannelNotifier(this._channels);
  final List<Channel> _channels;

  @override
  Future<List<Channel>> build() async => _channels;
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();
}

TeamMember _member(String id, String name) => TeamMember(
  id: id,
  email: '${name.toLowerCase()}@zedu.chat',
  role: 'member',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
  name: name,
);

Channel _channel(String id, String name) => Channel(
  id: id,
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'owner',
);

Future<ProviderContainer> _pumpView(
  WidgetTester tester, {
  List<TeamMember> members = const [],
  List<Channel> channels = const [],
  bool loading = false,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      userProfileNotifierProvider.overrideWith(
        () => _FakeUserProfileNotifier(
          UserProfileState(isLoading: loading, teamMembers: members),
        ),
      ),
      channelProvider.overrideWith(() => _FakeChannelNotifier(channels)),
      authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
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
  // A spinner never settles.
  if (loading) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  return container;
}

void main() {
  final alice = _member('u1', 'Alice');
  final bob = _member('u2', 'Bob');
  final general = _channel('c1', 'general');
  final design = _channel('c2', 'design');

  testWidgets('people and channels show as the page opens, before typing', (
    tester,
  ) async {
    await _pumpView(tester, members: [alice, bob], channels: [general, design]);

    expect(find.text('alice@zedu.chat'), findsOneWidget);
    expect(find.text('bob@zedu.chat'), findsOneWidget);
    expect(find.text('#general'), findsOneWidget);
    expect(find.text('#design'), findsOneWidget);
  });

  testWidgets('typing filters both people and channels', (tester) async {
    await _pumpView(tester, members: [alice, bob], channels: [general, design]);

    await tester.enterText(find.byType(TextField).first, 'de');
    await tester.pump();

    expect(find.text('#design'), findsOneWidget);
    expect(find.text('#general'), findsNothing);
    expect(find.text('alice@zedu.chat'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'bo');
    await tester.pump();

    expect(find.text('bob@zedu.chat'), findsOneWidget);
    expect(find.text('alice@zedu.chat'), findsNothing);
    expect(find.text('#design'), findsNothing);
  });

  testWidgets('a selected person is no longer suggested', (tester) async {
    await _pumpView(tester, members: [alice, bob]);

    await tester.tap(find.text('alice@zedu.chat'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'Alice'), findsOneWidget);
    expect(find.text('alice@zedu.chat'), findsNothing);
    expect(find.text('bob@zedu.chat'), findsOneWidget);
  });

  testWidgets('Down then Enter adds the highlighted person', (tester) async {
    await _pumpView(tester, members: [alice, bob]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'Bob'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Alice'), findsNothing);
  });

  testWidgets('Enter on a channel opens it', (tester) async {
    final container = await _pumpView(tester, channels: [general]);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final active = container.read(activeChatProvider);
    expect(active.type, ActiveChatType.channel);
    expect(active.id, 'general');
  });

  testWidgets('a search that matches nothing says so', (tester) async {
    await _pumpView(tester, members: [alice], channels: [general]);

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pump();

    expect(find.text('No people or channels match "zzz"'), findsOneWidget);
  });

  testWidgets('shows a loading row while people load', (tester) async {
    await _pumpView(tester, loading: true);
    expect(find.text('Loading people and channels...'), findsOneWidget);
  });

  testWidgets('with no people or channels it says there is nothing yet', (
    tester,
  ) async {
    await _pumpView(tester);
    expect(find.text('No people or channels to suggest yet'), findsOneWidget);
  });
}
