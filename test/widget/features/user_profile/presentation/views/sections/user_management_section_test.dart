import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

Widget buildUnderTest(List<TeamMember> members) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: UserManagementSection(
            members: members,
            isSaving: false,
            onInvite: ({required email, required role}) async {},
            onUpdate: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    ),
  );
}

List<TeamMember> createMembers(int count) {
  return List.generate(
    count,
    (i) => TeamMember(
      id: '$i',
      email: 'member$i@example.com',
      name: 'Member $i',
      role: i % 2 == 0 ? 'User' : 'Administrator',
      dateJoined: 'Oct 1, 2026',
      status: TeamMemberStatus.active,
    ),
  );
}

void main() {
  testWidgets('offers bulk invitation alongside the existing member table', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildUnderTest(createMembers(2)));
    await tester.pumpAndSettle();
    expect(find.text('Invite multiple people'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Invites'), findsOneWidget);
  });

  group('UserManagementSection role filter (Ziki #2389)', () {
    TeamMember member(String email, String role) => TeamMember(
      id: email,
      email: email,
      name: email,
      role: role,
      dateJoined: 'Oct 1, 2026',
      status: TeamMemberStatus.active,
    );

    Future<void> pickRole(WidgetTester tester, String role) async {
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(role).last);
      await tester.pumpAndSettle();
    }

    testWidgets('offers every role members have and filters by it', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest([
          member('owner@example.com', 'Owner'),
          member('lead@example.com', 'Project Lead'),
          member('user@example.com', 'User'),
        ]),
      );
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(dropdown.items!.map((item) => item.value), [
        'All Roles',
        'Owner',
        'Project Lead',
        'User',
      ]);

      await pickRole(tester, 'Owner');

      expect(find.text('owner@example.com'), findsOneWidget);
      expect(find.text('lead@example.com'), findsNothing);
      expect(find.text('user@example.com'), findsNothing);
    });

    testWidgets('keeps the selected role when its last member goes', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest([
          member('owner@example.com', 'Owner'),
          member('user@example.com', 'User'),
        ]),
      );
      await tester.pumpAndSettle();
      await pickRole(tester, 'Owner');

      await tester.pumpWidget(
        buildUnderTest([member('user@example.com', 'User')]),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        'Owner',
      );
      expect(find.text('user@example.com'), findsNothing);
    });
  });

  group('UserManagementSection Invites tab navigation (#205 / Ziki #204)', () {
    testWidgets(
      'clicking Invites tab switches to invites view with empty state',
      (tester) async {
        await tester.pumpWidget(buildUnderTest(createMembers(3)));
        await tester.pumpAndSettle();

        expect(find.text('member0@example.com'), findsOneWidget);
        expect(find.text('No pending invitations'), findsNothing);

        // Tap Invites tab
        await tester.tap(find.text('Invites'));
        await tester.pumpAndSettle();

        expect(find.text('No pending invitations'), findsOneWidget);
        expect(find.text('member0@example.com'), findsNothing);

        // Tap Members tab to switch back
        await tester.tap(find.text('Members'));
        await tester.pumpAndSettle();

        expect(find.text('member0@example.com'), findsOneWidget);
        expect(find.text('No pending invitations'), findsNothing);
      },
    );

    testWidgets('renders pending invitations in invites tab when present', (
      tester,
    ) async {
      final membersWithPending = [
        const TeamMember(
          id: '1',
          email: 'active@example.com',
          name: 'Active User',
          role: 'Administrator',
          dateJoined: 'Oct 1, 2026',
          status: TeamMemberStatus.active,
        ),
        const TeamMember(
          id: '2',
          email: 'invited@example.com',
          name: 'Invited User',
          role: 'User',
          dateJoined: 'Oct 2, 2026',
          status: TeamMemberStatus.pending,
        ),
      ];

      await tester.pumpWidget(buildUnderTest(membersWithPending));
      await tester.pumpAndSettle();

      // Invites badge should show '1'
      expect(find.text('Invites'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Switch to Invites
      await tester.tap(find.text('Invites'));
      await tester.pumpAndSettle();

      // Should show invited user in the table, not empty state
      expect(find.text('No pending invitations'), findsNothing);
      expect(find.text('invited@example.com'), findsOneWidget);
      expect(find.text('Date Invited'), findsOneWidget);
    });
  });

  group('UserManagementSection Date Joined (Ziki #2392)', () {
    const timestamp = '2026-11-03T12:06:34.098981Z';

    testWidgets('shows a member timestamp as a readable date', (tester) async {
      await tester.pumpWidget(
        buildUnderTest(const [
          TeamMember(
            id: '1',
            email: 'active@example.com',
            name: 'Active User',
            role: 'Administrator',
            dateJoined: timestamp,
            status: TeamMemberStatus.active,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nov 3, 2026'), findsOneWidget);
      expect(find.text(timestamp), findsNothing);
    });

    testWidgets('formats an invite timestamp and keeps "Pending"', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest(const [
          TeamMember(
            id: '1',
            email: 'sent@example.com',
            name: 'Sent',
            role: 'User',
            dateJoined: timestamp,
            status: TeamMemberStatus.pending,
          ),
          TeamMember(
            id: '2',
            email: 'unsent@example.com',
            name: 'Unsent',
            role: 'User',
            dateJoined: 'Pending',
            status: TeamMemberStatus.pending,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invites'));
      await tester.pumpAndSettle();

      expect(find.text('Nov 3, 2026'), findsOneWidget);
      // The unsent invite's date, plus both invites' status pills.
      expect(find.text('Pending'), findsNWidgets(3));
      expect(find.text(timestamp), findsNothing);
    });
  });

  group('UserManagementSection remove confirm (Ziki #2928)', () {
    testWidgets('a pending invite is not described as a team member', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        buildUnderTest(const [
          TeamMember(
            id: '2',
            email: 'invited@example.com',
            name: 'Invited User',
            role: 'User',
            dateJoined: 'Oct 2, 2026',
            status: TeamMemberStatus.pending,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invites'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove invite'));
      await tester.pumpAndSettle();

      expect(find.text('Remove invitation?'), findsOneWidget);
      expect(
        find.text(
          'The invitation to invited@example.com will be cancelled. They will not join this organization.',
        ),
        findsOneWidget,
      );
      expect(find.text('Remove invite'), findsOneWidget);
      expect(find.text('Remove team member?'), findsNothing);
    });

    testWidgets('removing an active member still says team member', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        buildUnderTest(const [
          TeamMember(
            id: '1',
            email: 'active@example.com',
            name: 'Active User',
            role: 'Administrator',
            dateJoined: 'Oct 1, 2026',
            status: TeamMemberStatus.active,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove member'));
      await tester.pumpAndSettle();

      expect(find.text('Remove team member?'), findsOneWidget);
      expect(
        find.text('active@example.com will lose access to this organization.'),
        findsOneWidget,
      );
      expect(find.text('Remove member'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('UserManagementSection remove mounted check (Ziki #9089)', () {
    testWidgets(
      'confirming member removal calls onRemove when UserManagementSection is mounted',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final removedIds = <String>[];
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: UserManagementSection(
                    members: const [
                      TeamMember(
                        id: 'member-1',
                        email: 'active@example.com',
                        name: 'Active User',
                        role: 'Administrator',
                        dateJoined: 'Oct 1, 2026',
                        status: TeamMemberStatus.active,
                      ),
                    ],
                    isSaving: false,
                    onInvite: ({required email, required role}) async {},
                    onUpdate: (_) {},
                    onRemove: removedIds.add,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Remove member'));
        await tester.pumpAndSettle();

        expect(find.text('Remove team member?'), findsOneWidget);
        await tester.tap(find.text('Remove member'));
        await tester.pumpAndSettle();

        expect(removedIds, ['member-1']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'confirming member removal does not call onRemove if UserManagementSection unmounted while dialog is open',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final removedIds = <String>[];
        Widget buildHarness({required bool showSection}) {
          return ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: showSection
                    ? SingleChildScrollView(
                        child: UserManagementSection(
                          members: const [
                            TeamMember(
                              id: 'member-1',
                              email: 'active@example.com',
                              name: 'Active User',
                              role: 'Administrator',
                              dateJoined: 'Oct 1, 2026',
                              status: TeamMemberStatus.active,
                            ),
                          ],
                          isSaving: false,
                          onInvite: ({required email, required role}) async {},
                          onUpdate: (_) {},
                          onRemove: removedIds.add,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildHarness(showSection: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Remove member'));
        await tester.pumpAndSettle();

        expect(find.text('Remove team member?'), findsOneWidget);

        // Unmount UserManagementSection while the confirmation dialog stays open
        await tester.pumpWidget(buildHarness(showSection: false));
        await tester.pump();

        expect(find.byType(UserManagementSection), findsNothing);
        expect(find.text('Remove member'), findsOneWidget);

        await tester.tap(find.text('Remove member'));
        await tester.pumpAndSettle();

        expect(removedIds, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'confirming invite removal does not call onRemove if UserManagementSection unmounted while dialog is open',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final removedIds = <String>[];
        Widget buildHarness({required bool showSection}) {
          return ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: showSection
                    ? SingleChildScrollView(
                        child: UserManagementSection(
                          members: const [
                            TeamMember(
                              id: 'invite-1',
                              email: 'invited@example.com',
                              name: 'Invited User',
                              role: 'User',
                              dateJoined: 'Oct 2, 2026',
                              status: TeamMemberStatus.pending,
                            ),
                          ],
                          isSaving: false,
                          onInvite: ({required email, required role}) async {},
                          onUpdate: (_) {},
                          onRemove: removedIds.add,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildHarness(showSection: true));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Invites'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Remove invite'));
        await tester.pumpAndSettle();

        expect(find.text('Remove invitation?'), findsOneWidget);

        // Unmount UserManagementSection while the confirmation dialog stays open
        await tester.pumpWidget(buildHarness(showSection: false));
        await tester.pump();

        expect(find.byType(UserManagementSection), findsNothing);
        expect(find.text('Remove invite'), findsOneWidget);

        await tester.tap(find.text('Remove invite'));
        await tester.pumpAndSettle();

        expect(removedIds, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('renders active tab count badge with primaryBg token', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: SingleChildScrollView(
            child: UserManagementSection(
              members: const [],
              isSaving: false,
              onInvite: ({required email, required role}) async {},
              onUpdate: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final countFinder = find.ancestor(
      of: find.text('0'),
      matching: find.byType(Container),
    );
    expect(countFinder, findsWidgets);
    final containerWidget = tester.widget<Container>(countFinder.first);
    final decoration = containerWidget.decoration as BoxDecoration?;
    expect(decoration?.color, equals(AppPalette.light.primaryBg));
  });

  group('UserManagementSection pagination page-jump (Ziki #240)', () {
    testWidgets(
      'renders page jump input and navigates directly to requested page',
      (tester) async {
        final members = List.generate(
          25,
          (i) => TeamMember(
            id: '$i',
            email: 'member$i@example.com',
            name: 'Member $i',
            role: 'User',
            dateJoined: 'Oct 1, 2026',
            status: TeamMemberStatus.active,
          ),
        );

        await tester.pumpWidget(buildUnderTest(members));
        await tester.pumpAndSettle();

        // Initial state on page 1 of 3
        expect(find.text('1'), findsWidgets);
        expect(find.text(' of 3'), findsOneWidget);
        expect(
          find.byKey(const Key('user_management_page_jump_input')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('user_management_page_jump_button')),
          findsOneWidget,
        );
        expect(find.text('member0@example.com'), findsOneWidget);
        expect(find.text('member9@example.com'), findsOneWidget);
        expect(find.text('member10@example.com'), findsNothing);

        // Jump to page 3 via Go button
        final jumpInput = find.byKey(
          const Key('user_management_page_jump_input'),
        );
        await tester.enterText(jumpInput, '3');
        await tester.tap(
          find.byKey(const Key('user_management_page_jump_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 of 3'), findsOneWidget);
        expect(find.text('member20@example.com'), findsOneWidget);
        expect(find.text('member0@example.com'), findsNothing);

        // Jump to page 2 via Enter key
        await tester.enterText(jumpInput, '2');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.text('2 of 3'), findsOneWidget);
        expect(find.text('member10@example.com'), findsOneWidget);

        // Out of bounds input clamps to valid range
        await tester.enterText(jumpInput, '99');
        await tester.tap(
          find.byKey(const Key('user_management_page_jump_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 of 3'), findsOneWidget);
        expect(find.text('member20@example.com'), findsOneWidget);
      },
    );
  });
  group('UserManagementSection table layout and overflow (#204)', () {
    testWidgets('renders long email, long role, and long date without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final members = [
        const TeamMember(
          id: 'long-member-1',
          email:
              'verylongemailaddressthatcouldcauseoverflow@organizationdomain.com',
          role: '019fcd17-4b53-72d3-bac3-4586dc029b5a',
          dateJoined: 'November 28, 2026, 11:59 PM',
          status: TeamMemberStatus.active,
        ),
      ];

      await tester.pumpWidget(buildUnderTest(members));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'verylongemailaddressthatcouldcauseoverflow@organizationdomain.com',
        ),
        findsOneWidget,
      );
      expect(find.text('019fcd17-4b53-72d3-bac3-4586dc029b5a'), findsOneWidget);
      expect(find.text('November 28, 2026, 11:59 PM'), findsOneWidget);
    });

    testWidgets('renders without overflow on narrow window dimensions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildUnderTest(createMembers(5)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('member0@example.com'), findsOneWidget);
    });

    testWidgets(
      'search and filter toolbar stacks responsively at reduced window widths without overflow',
      (tester) async {
        // Window width where fixed-width 300px + dropdown previously threw 35px overflow
        tester.view.physicalSize = const Size(440, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildUnderTest(createMembers(3)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('All Roles'), findsOneWidget);

        // Verify search input still functions when stacked
        await tester.enterText(find.byType(TextField), 'member1');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('member1@example.com'), findsOneWidget);
        expect(find.text('member0@example.com'), findsNothing);
      },
    );

    testWidgets(
      'table columns and action buttons remain accessible via horizontal scroll at reduced widths',
      (tester) async {
        tester.view.physicalSize = const Size(500, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildUnderTest(createMembers(2)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Check horizontal scrollbar is present
        expect(find.byType(Scrollbar), findsOneWidget);

        // Scroll horizontally to ensure the rightmost Actions column is fully reached
        final scrollableFinder = find.byType(SingleChildScrollView).last;
        await tester.drag(scrollableFinder, const Offset(-300, 0));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.edit_outlined), findsWidgets);
        expect(find.byIcon(Icons.delete_outline), findsWidgets);
      },
    );
  });
}
