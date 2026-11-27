import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

const _owner = TeamMember(
  id: 'user-1',
  email: 'owner@zedu.test',
  role: 'Owner',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
);

Future<List<TeamMember>> _open(
  WidgetTester tester,
  TeamMember member, {
  List<String> roles = const [],
}) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  final updates = <TeamMember>[];
  await tester.pumpWidget(
    buildTestMaterialApp(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showEditMemberDialog(
              context,
              member,
              updates.add,
              roles: roles,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return updates;
}

void main() {
  testWidgets('opens for a role outside the default three', (tester) async {
    await _open(tester, _owner);

    expect(tester.takeException(), isNull);
    expect(find.text('Edit Team Member'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
  });

  testWidgets('lists the organisation roles and saves the chosen one', (
    tester,
  ) async {
    final updates = await _open(
      tester,
      _owner,
      roles: const ['Owner', 'Admin', 'Guest'],
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsWidgets);
    expect(find.text('Guest'), findsWidgets);
    expect(find.text('Manager'), findsNothing);

    await tester.tap(find.text('Guest').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(updates.single.role, 'Guest');
    expect(updates.single.id, 'user-1');
  });
}
