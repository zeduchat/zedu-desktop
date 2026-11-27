import 'package:zedu/core/core.dart';
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

  for (final brightness in Brightness.values) {
    testWidgets(
      'role card details use the palette in ${brightness.name} mode',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const Scaffold(
              body: RolesAndPermissionsSection(
                roles: [
                  RolePermission(
                    role: 'Admin',
                    description: 'Manages the workspace',
                    permissions: ['Invite members'],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.text('Admin'));
        await tester.pump();

        final description = find.text('Manages the workspace');
        final secondary = tester.element(description).colors.textSecondary;
        expect(tester.widget<Text>(description).style?.color, secondary);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.keyboard_arrow_right)).color,
          secondary,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.check_circle_outline)).color,
          secondary,
        );
      },
    );
  }
}
