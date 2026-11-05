import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/test_material_app.dart';

void main() {
  group('ProfileStatusPill', () {
    testWidgets('renders active status with capitalization', (tester) async {
      await tester.pumpWidget(
        buildTestMaterialApp(const ProfileStatusPill(status: 'active')),
      );

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders non-active status with capitalization', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(const ProfileStatusPill(status: 'inactive')),
      );

      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('handles empty status string without throwing RangeError', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(const ProfileStatusPill(status: '')),
      );

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('handles whitespace-only status string gracefully', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(const ProfileStatusPill(status: '   ')),
      );

      expect(find.text('Unknown'), findsOneWidget);
    });
  });
}
