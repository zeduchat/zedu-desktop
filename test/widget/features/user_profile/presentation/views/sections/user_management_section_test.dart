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
}
