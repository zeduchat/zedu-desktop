import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

// Fake notifier that avoids GetIt/locator setup while remaining type-compatible
// with authNotifierProvider (which is NotifierProvider<AuthNotifier, AuthState>).
class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

// The default test font has different metrics, so load the app's real fonts.
Future<void> loadAppFonts() async {
  for (final family in ['Lato', 'Roboto']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular', 'Bold']) {
      final bytes = File('assets/fonts/$family/$family-$weight.ttf');
      loader.addFont(
        Future.value(ByteData.sublistView(bytes.readAsBytesSync())),
      );
    }
    await loader.load();
  }
}

Future<void> pumpSignUpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authNotifierProvider.overrideWith(() => FakeAuthNotifier())],
      child: MaterialApp(theme: AppTheme.light, home: const SignUpView()),
    ),
  );
  await tester.pump();
}

ScrollPosition signUpScrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

// A desktop app: Linux gives compact VisualDensity, which shortens fields and
// buttons. The default test platform (Android) lays the column out taller.
final linuxOnly = TargetPlatformVariant.only(TargetPlatform.linux);

Finder get termsText => find.textContaining('By signing up');

void main() {
  setUpAll(loadAppFonts);

  group('SignUpView Tab navigation', () {
    testWidgets('Tab moves directly between registration fields', (
      tester,
    ) async {
      await pumpSignUpAt(tester, const Size(1280, 720));

      await tester.tap(find.byType(TextFormField).at(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final emailField = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).at(1),
          matching: find.byType(EditableText),
        ),
      );
      expect(emailField.focusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final passwordField = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).at(2),
          matching: find.byType(EditableText),
        ),
      );
      expect(passwordField.focusNode.hasFocus, isTrue);
    });
  });
}
