import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _MockDmRepository extends Mock implements DmRepository {}

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

  late _MockDmRepository dms;

  setUp(() => dms = _MockDmRepository());

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
        currentOrgIdProvider.overrideWithValue('org-1'),
        dmRepositoryProvider.overrideWithValue(dms),
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

  Future<void> selectAlice(WidgetTester tester) async {
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.tap(find.text('alice@zedu.chat'));
    await tester.pump();
  }

  ElevatedButton createButton(WidgetTester tester) => tester
      .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Create'));

  testWidgets('Create is enabled once one person is selected', (tester) async {
    await pumpView(tester);
    expect(createButton(tester).onPressed, isNull);

    await selectAlice(tester);

    expect(createButton(tester).onPressed, isNotNull);
    expect(find.textContaining('Ready to message Alice'), findsOneWidget);
  });

  testWidgets('one person opens the 1:1 DM instead of creating a group', (
    tester,
  ) async {
    when(
      () => dms.openConversation(orgId: 'org-1', participantId: 'u1'),
    ).thenAnswer((_) async => (channelId: 'c-1', participantId: 'u1'));
    final container = await pumpView(tester);

    await selectAlice(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pump();

    verify(
      () => dms.openConversation(orgId: 'org-1', participantId: 'u1'),
    ).called(1);
    final selected = container.read(selectedDmProvider);
    expect(selected?.channelId, 'c-1');
    expect(selected?.participantId, 'u1');
    expect(selected?.username, 'Alice');
    expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
    expect(find.textContaining('created successfully'), findsNothing);
  });

  testWidgets('a failed open shows an error and keeps the page', (
    tester,
  ) async {
    when(
      () => dms.openConversation(orgId: 'org-1', participantId: 'u1'),
    ).thenThrow(const ApiFailure(message: 'offline'));
    final container = await pumpView(tester);

    await selectAlice(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't open chat. Please try again."), findsOneWidget);
    expect(container.read(selectedDmProvider), isNull);
  });
}
