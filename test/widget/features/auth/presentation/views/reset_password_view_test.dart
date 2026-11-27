import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

// Fake notifier that avoids GetIt/locator setup while remaining type-compatible
// with authNotifierProvider (which is NotifierProvider<AuthNotifier, AuthState>).
class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

/// Records the code a reset was submitted with.
class _RecordingAuthNotifier extends FakeAuthNotifier {
  final tokens = <String>[];

  @override
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    tokens.add(token);
    return false;
  }
}

Widget buildResetPasswordViewUnderTest({AuthNotifier? notifier}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => notifier ?? FakeAuthNotifier()),
    ],
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

  group('ResetPasswordView code boxes', () {
    List<String> codeDigits(WidgetTester tester) => tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .take(6)
        .map((field) => field.controller!.text)
        .toList();

    testWidgets(
      'Backspace walks back through the boxes and clears each digit',
      (tester) async {
        await tester.pumpWidget(buildResetPasswordViewUnderTest());
        final boxes = find.byType(TextFormField);
        await tester.enterText(boxes.at(0), '1');
        await tester.enterText(boxes.at(1), '2');
        await tester.enterText(boxes.at(2), '3');
        expect(codeDigits(tester), ['1', '2', '3', '', '', '']);

        // Focus now sits on the empty fourth box.
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.pump();
        }

        expect(codeDigits(tester), ['', '', '', '', '', '']);
      },
    );

    testWidgets('pasting the whole code fills every box and submits it', (
      tester,
    ) async {
      final notifier = _RecordingAuthNotifier();
      await tester.pumpWidget(
        buildResetPasswordViewUnderTest(notifier: notifier),
      );
      final fields = find.byType(TextFormField);

      await tester.enterText(fields.at(0), '123456');
      await tester.pump();
      expect(codeDigits(tester), ['1', '2', '3', '4', '5', '6']);

      await tester.enterText(fields.at(6), 'NewSecret123!');
      await tester.enterText(fields.at(7), 'NewSecret123!');
      await tester.ensureVisible(find.byType(AppButton));
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(notifier.tokens, ['123456']);
    });

    testWidgets('a code pasted into a later box still fills every box', (
      tester,
    ) async {
      await tester.pumpWidget(buildResetPasswordViewUnderTest());

      await tester.enterText(find.byType(TextFormField).at(3), '654321');
      await tester.pump();

      expect(codeDigits(tester), ['6', '5', '4', '3', '2', '1']);
    });

    testWidgets('a partial paste fills boxes from where it was pasted', (
      tester,
    ) async {
      await tester.pumpWidget(buildResetPasswordViewUnderTest());

      await tester.enterText(find.byType(TextFormField).at(2), '789');
      await tester.pump();

      expect(codeDigits(tester), ['', '', '7', '8', '9', '']);
    });

    testWidgets('Backspace in the first empty box does nothing', (
      tester,
    ) async {
      await tester.pumpWidget(buildResetPasswordViewUnderTest());
      await tester.tap(find.byType(TextFormField).at(0));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(codeDigits(tester), ['', '', '', '', '', '']);
      expect(tester.takeException(), isNull);
    });
  });
}
