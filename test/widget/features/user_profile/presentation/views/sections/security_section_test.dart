import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

Widget buildSecuritySection(
  List<SecuritySession> sessions, {
  Future<void> Function(String sessionId)? onRevoke,
}) {
  return buildTestMaterialApp(
    Scaffold(
      body: SecuritySection(
        sessions: sessions,
        isSaving: false,
        onRevoke: onRevoke,
        onChangePassword:
            ({
              required String currentPassword,
              required String newPassword,
            }) async => const Success<void>(null),
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

  testWidgets('the sessions table header uses the background token', (
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

    final table = tester.widget<DataTable>(find.byType(DataTable));

    expect(table.headingRowColor!.resolve({}), AppPalette.light.background);
  });

  group('revoking a session (Ziki #2797)', () {
    // The table is wider than the default 800px test surface.
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(
        1600,
        900,
      );
      binding.platformDispatcher.views.first.devicePixelRatio = 1;
    });
    tearDown(() {
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .views
          .first
          .reset();
    });

    const live = SecuritySession(
      id: 's1',
      device: 'Chrome on Linux',
      location: 'Lagos',
      date: '4 Nov 2026',
      lastActive: 'Now',
      status: 'Active',
      isLive: true,
    );
    const ended = SecuritySession(
      id: 's2',
      device: 'Firefox',
      location: 'Abuja',
      date: '3 Nov 2026',
      lastActive: 'Yesterday',
      status: 'Signed out',
    );

    testWidgets('only live sessions offer Sign out', (tester) async {
      await tester.pumpWidget(
        buildSecuritySection(const [live, ended], onRevoke: (_) async {}),
      );

      expect(find.text('Action'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sign out'), findsOneWidget);
    });

    testWidgets('confirming the dialog revokes that session', (tester) async {
      final revoked = <String>[];
      await tester.pumpWidget(
        buildSecuritySection(const [
          live,
        ], onRevoke: (id) async => revoked.add(id)),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out this session?'), findsOneWidget);
      expect(revoked, isEmpty);

      await tester.tap(find.widgetWithText(AppButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(revoked, ['s1']);
    });

    testWidgets('cancelling the dialog keeps the session', (tester) async {
      final revoked = <String>[];
      await tester.pumpWidget(
        buildSecuritySection(const [
          live,
        ], onRevoke: (id) async => revoked.add(id)),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(revoked, isEmpty);
    });

    testWidgets('without onRevoke there is no action column', (tester) async {
      await tester.pumpWidget(buildSecuritySection(const [live]));

      expect(find.text('Action'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
    });
  });
}
