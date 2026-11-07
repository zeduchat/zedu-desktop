import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final User? _user;
  _FakeAuthNotifier([this._user]);

  @override
  AuthState build() {
    return AuthState(
      status: _user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      user: _user,
    );
  }
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  final List<TeamMember> _members;
  _FakeUserProfileNotifier(this._members);

  @override
  UserProfileState build() {
    return UserProfileState(isLoading: false, teamMembers: _members);
  }
}

TeamMember _member(String id, String name) => TeamMember(
  id: id,
  email: '${name.toLowerCase()}@zedu.chat',
  role: 'member',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
  name: name,
);

Future<void> _pumpView(WidgetTester tester, List<TeamMember> members) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileNotifierProvider.overrideWith(
          () => _FakeUserProfileNotifier(members),
        ),
      ],
      child: buildTestMaterialApp(const Scaffold(body: NewGroupChatView())),
    ),
  );
}

// A desktop pointer unfocuses a text field on press outside it, which is what
// removed the suggestion list before a row tap could complete.
final _desktopPointer = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  final testMembers = [
    const TeamMember(
      id: 'member-1',
      name: '',
      email: 'emptyname@zedu.test',
      role: 'Member',
      dateJoined: 'Jan 1, 2026',
      status: TeamMemberStatus.active,
    ),
    const TeamMember(
      id: 'member-2',
      name: '   ',
      email: 'whitespace@zedu.test',
      role: 'Member',
      dateJoined: 'Jan 1, 2026',
      status: TeamMemberStatus.active,
    ),
    const TeamMember(
      id: 'member-3',
      name: null,
      email: 'nullname@zedu.test',
      role: 'Member',
      dateJoined: 'Jan 1, 2026',
      status: TeamMemberStatus.active,
    ),
    const TeamMember(
      id: 'member-4',
      name: 'Alice Cooper',
      email: 'alice@zedu.test',
      role: 'Admin',
      dateJoined: 'Jan 1, 2026',
      status: TeamMemberStatus.active,
    ),
  ];

  Widget buildWidget({List<TeamMember>? members, User? signedInUser}) {
    return ProviderScope(
      overrides: [
        userProfileNotifierProvider.overrideWith(
          () => _FakeUserProfileNotifier(members ?? testMembers),
        ),
        authNotifierProvider.overrideWith(
          () => _FakeAuthNotifier(signedInUser),
        ),
      ],
      child: buildTestMaterialApp(
        const Scaffold(
          body: SizedBox(width: 1200, height: 900, child: NewGroupChatView()),
        ),
      ),
    );
  }

  Finder findSearchField() {
    return find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText?.contains('#a-channel') == true,
    );
  }

  testWidgets(
    'renders contact list without crashing when members have empty or whitespace names',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final searchField = findSearchField();
      expect(searchField, findsOneWidget);

      await tester.tap(searchField);
      await tester.pumpAndSettle();

      // Contact tiles should be displayed without throwing RangeError
      expect(find.text('emptyname'), findsOneWidget);
      expect(find.text('whitespace'), findsOneWidget);
      expect(find.text('nullname'), findsOneWidget);
      expect(find.text('Alice Cooper'), findsOneWidget);
    },
  );

  testWidgets(
    'renders selected member chip with safe initials and fallback label for empty name',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(findSearchField());
      await tester.pumpAndSettle();

      // Tap on member with empty name ('emptyname@zedu.test')
      await tester.tap(find.text('emptyname'));
      await tester.pumpAndSettle();

      // Verify selected member chip renders with label and without error
      expect(find.byType(Chip), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text('emptyname'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(Chip), matching: find.text('E')),
        findsOneWidget,
      );
    },
  );
  testWidgets('renders validation helper in neutral style on initial load', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    final helperText = tester.widget<Text>(
      find.textContaining('Select at least 2 members'),
    );
    expect(helperText.style?.color, isNot(equals(AppPalette.light.error)));
    expect(helperText.style?.color, equals(AppPalette.light.textSecondary));
  });

  testWidgets('does not suggest signed-in user in suggestions list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final currentUser = User(
      id: 'member-4',
      firstName: 'Alice',
      lastName: 'Cooper',
      email: 'alice@zedu.test',
      phone: '',
      username: 'alice',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026, 1, 1),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'org-1',
      avatarUrl: '',
      defaultAvatarUrl: '',
    );

    await tester.pumpWidget(buildWidget(signedInUser: currentUser));
    await tester.pumpAndSettle();

    await tester.tap(findSearchField());
    await tester.pumpAndSettle();

    // Alice Cooper is the signed-in user and should NOT be suggested
    expect(find.text('Alice Cooper'), findsNothing);
    expect(find.text('emptyname'), findsOneWidget);
  });

  testWidgets(
    'displays dynamic contextual placeholder reflecting recipient selection',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // 1. Initial state (0 recipients)
      expect(
        find.text('Select a recipient above to start messaging...'),
        findsOneWidget,
      );

      // 2. Select 1 recipient
      await tester.tap(findSearchField());
      await tester.pumpAndSettle();

      await tester.tap(find.text('emptyname'));
      await tester.pumpAndSettle();

      expect(find.text('Message @emptyname'), findsOneWidget);

      // 3. Select 2nd recipient
      await tester.tap(findSearchField());
      await tester.pumpAndSettle();

      await tester.tap(find.text('whitespace'));
      await tester.pumpAndSettle();

      expect(find.text('Message group (2 members)...'), findsOneWidget);
    },
  );

  group('NewGroupChatView suggestions', () {
    final alice = _member('u1', 'Alice');
    final bob = _member('u2', 'Bob');

    testWidgets('tapping a suggestion adds the member', (tester) async {
      await _pumpView(tester, [alice, bob]);

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(find.text('alice@zedu.chat'), findsOneWidget);

      // Pump between press and release, as a real click does: the frame in
      // between is where the list used to be removed.
      final click = await tester.startGesture(
        tester.getCenter(find.text('alice@zedu.chat')),
      );
      await tester.pump();
      await click.up();
      await tester.pump();

      expect(find.byType(Chip), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Alice'), findsOneWidget);
      expect(find.textContaining('Selected: 1/2'), findsOneWidget);
    }, variant: _desktopPointer);

    testWidgets('tapping elsewhere closes the list', (tester) async {
      await _pumpView(tester, [alice, bob]);

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(find.text('alice@zedu.chat'), findsOneWidget);

      await tester.tap(find.text('New message'));
      await tester.pump();

      expect(find.text('alice@zedu.chat'), findsNothing);
    }, variant: _desktopPointer);
  });
}
