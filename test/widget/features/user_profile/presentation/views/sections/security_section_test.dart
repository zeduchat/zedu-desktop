import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

Widget buildSecuritySection(
  List<SecuritySession> sessions, {
  Future<Result<void>> Function(String sessionId)? onRevokeSession,
}) {
  return buildTestMaterialApp(
    Scaffold(
      body: SingleChildScrollView(
        child: SecuritySection(
          sessions: sessions,
          isSaving: false,
          onChangePassword:
              ({
                required String currentPassword,
                required String newPassword,
              }) async => const Success<void>(null),
          onRevokeSession: onRevokeSession,
        ),
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
          id: 'session-1',
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

  testWidgets('renders Action column and Revoke button when onRevokeSession is provided', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildSecuritySection(
        const [
          SecuritySession(
            id: 'session-1',
            device: 'Chrome on Windows',
            location: 'Abuja',
            date: '5 Nov 2026',
            lastActive: '5m ago',
            status: 'Active',
          ),
        ],
        onRevokeSession: (id) async => const Success<void>(null),
      ),
    );

    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Revoke'), findsOneWidget);
  });

  testWidgets('tapping Revoke shows confirmation dialog and confirms revocation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String? revokedSessionId;
    await tester.pumpWidget(
      buildSecuritySection(
        const [
          SecuritySession(
            id: 'session-42',
            device: 'Safari on macOS',
            location: 'London',
            date: '5 Nov 2026',
            lastActive: '1m ago',
            status: 'Active',
          ),
        ],
        onRevokeSession: (id) async {
          revokedSessionId = id;
          return const Success<void>(null);
        },
      ),
    );

    // Tap Revoke button
    await tester.tap(find.byKey(const ValueKey('revoke-session-42')));
    await tester.pumpAndSettle();

    // Verify confirmation dialog is visible
    expect(find.text('Revoke Session'), findsOneWidget);
    expect(
      find.text('Are you sure you want to sign out and revoke the session on Safari on macOS (London)?'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Revoke in dialog
    await tester.tap(find.byKey(const ValueKey('confirm-revoke-button')));
    await tester.pumpAndSettle();

    // Verify callback was invoked with session ID
    expect(revokedSessionId, equals('session-42'));
    expect(find.text('Revoke Session'), findsNothing);
  });

  testWidgets('cancelling dialog does not revoke session', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var revoked = false;
    await tester.pumpWidget(
      buildSecuritySection(
        const [
          SecuritySession(
            id: 'session-99',
            device: 'Firefox on Android',
            location: 'Berlin',
            date: '5 Nov 2026',
            lastActive: '10m ago',
            status: 'Active',
          ),
        ],
        onRevokeSession: (id) async {
          revoked = true;
          return const Success<void>(null);
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('revoke-session-99')));
    await tester.pumpAndSettle();

    expect(find.text('Revoke Session'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(revoked, isFalse);
    expect(find.text('Revoke Session'), findsNothing);
  });
}
