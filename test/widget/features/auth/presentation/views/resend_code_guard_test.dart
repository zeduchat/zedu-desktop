import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _ResendAuth extends AuthNotifier {
  static final calls = <Completer<bool>>[];

  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);

  @override
  Future<bool> forgotPassword({required String email}) {
    final completer = Completer<bool>();
    calls.add(completer);
    return completer.future;
  }
}

void main() {
  setUp(_ResendAuth.calls.clear);

  testWidgets('Resend code sends one email on a double click and clears the '
      'old digits', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authNotifierProvider.overrideWith(_ResendAuth.new)],
        child: const MaterialApp(home: ResetPasswordView(email: 'a@b.co')),
      ),
    );
    await tester.pump();

    // Type a code, then wait out the 5 minute timer.
    final boxes = find.byType(TextField);
    await tester.enterText(boxes.at(0), '1');
    await tester.pump(const Duration(seconds: 301));

    final resend = find.textContaining('Resend code');
    await tester.tap(resend);
    await tester.tap(resend);
    await tester.pump();
    expect(_ResendAuth.calls, hasLength(1));

    _ResendAuth.calls.single.complete(true);
    await tester.pump();

    expect(tester.widget<TextField>(boxes.at(0)).controller!.text, isEmpty);

    // Let the toast's auto-dismiss timer and the countdown end cleanly.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
