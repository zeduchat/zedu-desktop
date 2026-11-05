import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  testWidgets('uses the approved roles and permissions subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestMaterialApp(const RolesAndPermissionsSection(roles: [])),
    );

    expect(find.text('Roles & permissions'), findsOneWidget);
    expect(
      find.text(
        'Define and manage roles, then assign their associated permissions.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Define and manage roles and their associated permissions.'),
      findsNothing,
    );
  });
}
