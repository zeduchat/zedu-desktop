import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  group('AuthHeaderStrip action', () {
    Future<List<String>> pumpStrip(WidgetTester tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: AuthHeaderStrip(
              promptText: 'Already have an account? ',
              actionText: 'Log in',
              onActionTap: () => taps.add('tap'),
            ),
          ),
        ),
      );
      return taps;
    }

    testWidgets('is announced as a button with its label', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpStrip(tester);

      expect(
        tester.getSemantics(find.widgetWithText(TextButton, 'Log in')),
        isSemantics(
          label: 'Log in',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      testWidgets('Tab focuses it and ${key.keyLabel} activates it', (
        tester,
      ) async {
        final taps = await pumpStrip(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        // The nearest focus node above the label is the button's own.
        expect(Focus.of(tester.element(find.text('Log in'))).hasFocus, isTrue);

        await tester.sendKeyEvent(key);
        await tester.pump();

        expect(taps, ['tap']);
      });
    }
  });
}
