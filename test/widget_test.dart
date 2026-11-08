import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/app/app.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class FakeSmokeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class FakeSmokeCreditsNotifier extends CreditsNotifier {
  @override
  CreditsState build() => const CreditsState();
}

void main() {
  group('App Startup Smoke Test', () {
    testWidgets('mounts root App and renders initial login route', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => FakeSmokeAuthNotifier()),
            creditsNotifierProvider.overrideWith(
              () => FakeSmokeCreditsNotifier(),
            ),
          ],
          child: const App(),
        ),
      );

      // Pump initial frame and settle router / async transitions
      await tester.pumpAndSettle();

      // Verify that the root App is mounted and running
      expect(find.byType(App), findsOneWidget);

      // Verify that the initial route (LoginView) is rendered
      expect(find.byType(LoginView), findsOneWidget);

      // Verify essential interactive form controls are present on the initial route
      expect(find.byType(TextFormField), findsWidgets);
    });
  });
}
