import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

Widget buildAuthHeaderStripUnderTest({
  String? promptText = 'Already have an account?',
  String? actionText = 'Sign up',
  VoidCallback? onActionTap,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: AuthHeaderStrip(
        promptText: promptText,
        actionText: actionText,
        onActionTap: onActionTap,
      ),
    ),
  );
}

void main() {
  group('AuthHeaderStrip', () {
    testWidgets('action is keyboard focusable and announced as a button', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildAuthHeaderStripUnderTest(onActionTap: () {}),
      );
      await tester.pumpAndSettle();

      final action = find.widgetWithText(TextButton, 'Sign up');
      expect(action, findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(action).getSemanticsData();
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.hasAction(SemanticsAction.tap), isTrue);

      final actionElement = tester.element(action);
      var focusIsInsideAction = false;
      FocusManager.instance.primaryFocus!.context!.visitAncestorElements((
        ancestor,
      ) {
        if (ancestor == actionElement) {
          focusIsInsideAction = true;
          return false;
        }
        return true;
      });
      expect(focusIsInsideAction, isTrue);
    });

    testWidgets('Enter activates the focused action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        buildAuthHeaderStripUnderTest(onActionTap: () => taps++),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('Space activates the focused action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        buildAuthHeaderStripUnderTest(onActionTap: () => taps++),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('mouse click still activates the action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        buildAuthHeaderStripUnderTest(onActionTap: () => taps++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Sign up'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('renders no action control without action copy', (
      tester,
    ) async {
      await tester.pumpWidget(buildAuthHeaderStripUnderTest(actionText: null));
      await tester.pumpAndSettle();

      expect(find.byType(TextButton), findsNothing);
      expect(find.text('Already have an account?'), findsNothing);
    });
  });
}
