import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

void main() {
  group('UserManagementSection Filters', () {
    final testMembers = [
      const TeamMember(
        id: '1',
        name: 'Alice Johnson',
        email: 'alice@zedu.chat',
        role: 'Administrator',
        dateJoined: 'Oct 1, 2026',
        status: TeamMemberStatus.active,
      ),
      const TeamMember(
        id: '2',
        name: 'Bob Smith',
        email: 'bob@zedu.chat',
        role: 'Manager',
        dateJoined: 'Oct 5, 2026',
        status: TeamMemberStatus.active,
      ),
      const TeamMember(
        id: '3',
        name: 'Charlie Brown',
        email: 'charlie@zedu.chat',
        role: 'User',
        dateJoined: 'Oct 10, 2026',
        status: TeamMemberStatus.active,
      ),
      const TeamMember(
        id: '4',
        name: 'Diana Prince',
        email: 'diana@invite.com',
        role: 'User',
        dateJoined: 'Pending',
        status: TeamMemberStatus.pending,
      ),
    ];

    Widget createTestWidget() {
      return buildTestMaterialApp(
        Scaffold(
          body: SingleChildScrollView(
            child: UserManagementSection(
              members: testMembers,
              isSaving: false,
              onInvite: (
                  {required String email, required String role}) async {},
              onUpdate: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders active members by default on initial load', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('alice@zedu.chat'), findsOneWidget);
      expect(find.text('bob@zedu.chat'), findsOneWidget);
      expect(find.text('charlie@zedu.chat'), findsOneWidget);
      // Pending invite should not be in Members tab
      expect(find.text('diana@invite.com'), findsNothing);
    });

    testWidgets('filters by name correctly in search field', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Alice');
      await tester.pumpAndSettle();

      expect(find.text('alice@zedu.chat'), findsOneWidget);
      expect(find.text('bob@zedu.chat'), findsNothing);
      expect(find.text('charlie@zedu.chat'), findsNothing);
      expect(find.text('Search: "alice"'), findsOneWidget);
    });

    testWidgets('switches to Invites tab and displays pending members', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final invitesTab = find.text('Invites');
      await tester.tap(invitesTab);
      await tester.pumpAndSettle();

      expect(find.text('diana@invite.com'), findsOneWidget);
      expect(find.text('alice@zedu.chat'), findsNothing);
      expect(find.text('Tab: Invites'), findsOneWidget);
    });

    testWidgets('clears all active filters in one click', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter search and switch tab
      await tester.enterText(find.byType(TextField).first, 'Bob');
      await tester.pumpAndSettle();

      expect(find.text('bob@zedu.chat'), findsOneWidget);
      expect(find.text('alice@zedu.chat'), findsNothing);

      // Tap clear all
      final clearAll = find.text('Clear all');
      expect(clearAll, findsOneWidget);
      await tester.tap(clearAll);
      await tester.pumpAndSettle();

      // Full list restored
      expect(find.text('alice@zedu.chat'), findsOneWidget);
      expect(find.text('bob@zedu.chat'), findsOneWidget);
      expect(find.text('charlie@zedu.chat'), findsOneWidget);
    });
  });
}
