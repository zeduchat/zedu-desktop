import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState(
    teamMembers: [
      TeamMember(
        id: 'u-1',
        email: 'ada@zedu.test',
        role: 'Admin',
        dateJoined: '2026-01-01',
        status: TeamMemberStatus.active,
        name: 'Ada Lovelace',
      ),
      TeamMember(
        id: 'u-2',
        email: 'bob@zedu.test',
        role: 'Member',
        dateJoined: '2026-01-02',
        status: TeamMemberStatus.active,
        name: 'Bob Stone',
      ),
    ],
  );
}

void main() {
  const hint = 'Select at least 2 members to start a group DM (Selected: 0/2)';

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileNotifierProvider.overrideWith(_FakeProfileNotifier.new),
        ],
        child: buildTestMaterialApp(const Scaffold(body: NewGroupChatView())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the member hint as plain guidance until someone is '
      'picked', (tester) async {
    await pump(tester);

    final text = tester.widget<Text>(find.text(hint));
    final colors = tester.element(find.text(hint)).colors;
    expect(text.style!.color, colors.textSecondary);
    expect(text.style!.color, isNot(colors.error));
  });

  testWidgets('turns the hint red only after a pick leaves fewer than 2', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ada Lovelace').first);
    await tester.pumpAndSettle();

    const afterOne =
        'Select at least 2 members to start a group DM (Selected: 1/2)';
    final text = tester.widget<Text>(find.text(afterOne));
    final colors = tester.element(find.text(afterOne)).colors;
    expect(text.style!.color, colors.error);
  });
}
