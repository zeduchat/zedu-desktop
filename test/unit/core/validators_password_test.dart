import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  // Reset password, the Change Password page and Settings > Change Password
  // all validate the new password with `Validators.validatePassword`.
  Future<String?> validate(WidgetTester tester, String value) async {
    String? result;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          result = Validators.validatePassword(context, value);
          return const SizedBox.shrink();
        },
      ),
    );
    return result;
  }

  testWidgets('rejects a password that starts or ends with a space', (
    tester,
  ) async {
    expect(
      await validate(tester, 'Secret123 '),
      Validators.passwordEdgeSpaceMessage,
    );
    expect(
      await validate(tester, ' Secret123'),
      Validators.passwordEdgeSpaceMessage,
    );
    expect(
      await validate(tester, 'Secret123\t'),
      Validators.passwordEdgeSpaceMessage,
    );
  });

  testWidgets('accepts spaces inside the password', (tester) async {
    expect(await validate(tester, 'Secret 123'), isNull);
  });

  testWidgets('still checks the other requirements', (tester) async {
    expect(await validate(tester, ''), 'Password is required');
    expect(
      await validate(tester, 'secret123'),
      'Password must contain at least one uppercase letter',
    );
    expect(await validate(tester, 'Secret123'), isNull);
  });
}
