import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

// Fake notifier that avoids GetIt/locator setup while remaining type-compatible
// with authNotifierProvider (which is NotifierProvider<AuthNotifier, AuthState>).
class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

Widget buildResetPasswordViewUnderTest() {
  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith(() => FakeAuthNotifier())],
    child: const MaterialApp(
      home: ResetPasswordView(email: 'test@example.com'),
    ),
  );
}

void main() {
  group('ResetPasswordView countdown timer', () {
    testWidgets('ticks the resend countdown', (tester) async {
      await tester.pumpWidget(buildResetPasswordViewUnderTest());

      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('after 4:59', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('does not call setState after the view is unmounted', (
      tester,
    ) async {
      await tester.pumpWidget(buildResetPasswordViewUnderTest());
      // The timer ticks one second after the view was built.
      await tester.pump(const Duration(seconds: 1));

      // Leave the view (any navigation away unmounts it) and let the polling
      // timer fire again afterwards; the periodic callback must bail out
      // instead of crashing with "setState() called after dispose()".
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => FakeAuthNotifier()),
          ],
          child: const MaterialApp(home: Scaffold(body: SizedBox())),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
    });
  });
}
