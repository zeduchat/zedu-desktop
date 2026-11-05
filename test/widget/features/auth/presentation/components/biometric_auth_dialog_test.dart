import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/auth/presentation/components/biometric_auth_dialog.dart';

void main() {
  group('BiometricAuthDialog', () {
    testWidgets('renders title, subtitle, and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BiometricAuthDialog(
              title: 'Test Biometric Title',
              subtitle: 'Test Biometric Subtitle',
            ),
          ),
        ),
      );

      expect(find.text('Test Biometric Title'), findsOneWidget);
      expect(find.text('Test Biometric Subtitle'), findsOneWidget);
      expect(find.text('Authenticate Now'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('triggers onCancel when Cancel is pressed', (tester) async {
      var cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricAuthDialog(onCancel: () => cancelled = true),
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets('renders fallback button when onFallback provided', (
      tester,
    ) async {
      var fallbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricAuthDialog(
              fallbackLabel: 'Use PIN',
              onFallback: () => fallbackCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Use PIN'), findsOneWidget);
      await tester.tap(find.text('Use PIN'));
      await tester.pumpAndSettle();

      expect(fallbackCalled, isTrue);
    });

    testWidgets('authenticates successfully and calls onSuccess', (
      tester,
    ) async {
      var successCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricAuthDialog(onSuccess: () => successCalled = true),
          ),
        ),
      );

      await tester.tap(find.text('Authenticate Now'));
      await tester.pump();

      expect(find.text('Scanning biometric credential...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('Biometric verification successful'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 450));
      expect(successCalled, isTrue);
    });
  });
}
