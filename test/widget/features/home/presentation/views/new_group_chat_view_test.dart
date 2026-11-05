import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeUserProfileNotifier extends UserProfileNotifier {
  final List<TeamMember> _members;
  _FakeUserProfileNotifier(this._members);

  @override
  UserProfileState build() {
    return UserProfileState(isLoading: false, teamMembers: _members);
  }
}

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

  Widget buildWidget({List<TeamMember>? members}) {
    return ProviderScope(
      overrides: [
        userProfileNotifierProvider.overrideWith(
          () => _FakeUserProfileNotifier(members ?? testMembers),
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
        find.descendant(of: find.byType(Chip), matching: find.text('EM')),
        findsOneWidget,
      );
    },
  );
}
