import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

Widget buildSecuritySection(List<SecuritySession> sessions) {
  return buildTestMaterialApp(
    Scaffold(
      body: SecuritySection(
        sessions: sessions,
        isSaving: false,
        onChangePassword:
            ({
              required String currentPassword,
              required String newPassword,
            }) async => const Success(null),
      ),
    ),
  );
}

void main() {
  testWidgets('empty sessions show a message without table headers', (
    tester,
  ) async {
    await tester.pumpWidget(buildSecuritySection([]));

    expect(find.text('No active sessions found'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Device'), findsNothing);
  });

  testWidgets('populated sessions retain the table and device row', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSecuritySection(const [
        SecuritySession(
          device: 'Chrome on Linux',
          location: 'Lagos',
          date: '4 Nov 2026',
          lastActive: 'Now',
          status: 'Active',
        ),
      ]),
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Chrome on Linux'), findsOneWidget);
    expect(find.text('No active sessions found'), findsNothing);
  });
}
