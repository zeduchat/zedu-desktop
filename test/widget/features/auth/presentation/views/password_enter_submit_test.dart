import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _RecordingAuth extends AuthNotifier {
  static final changeCalls = <String>[];

  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);

  @override
  Future<bool> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    changeCalls.add('$email|$oldPassword|$newPassword');
    return false;
  }
}

Widget _app(Widget home) => ProviderScope(
  overrides: [authNotifierProvider.overrideWith(_RecordingAuth.new)],
  child: MaterialApp(home: home),
);

void main() {
  setUp(_RecordingAuth.changeCalls.clear);

  group('Enter in the last password field', () {
    testWidgets('submits Change password', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const ChangePasswordView(email: 'a@b.co')));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'OldPass1!');
      await tester.enterText(fields.at(1), 'NewPass1!a');
      await tester.enterText(fields.at(2), 'NewPass1!a');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(_RecordingAuth.changeCalls, ['a@b.co|OldPass1!|NewPass1!a']);
    });

    testWidgets('submits Reset password (asks for the code)', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const ResetPasswordView(email: 'a@b.co')));
      await tester.pump();

      final fields = find.byType(TextFormField);
      final count = fields.evaluate().length;
      await tester.enterText(fields.at(count - 2), 'NewPass1!a');
      await tester.enterText(fields.at(count - 1), 'NewPass1!a');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // The form is valid and the submit ran: with no code typed, it asks for it.
      expect(
        find.text('Please enter the 6-digit verification code.'),
        findsOneWidget,
      );

      // Let the toast's auto-dismiss timer run out before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
