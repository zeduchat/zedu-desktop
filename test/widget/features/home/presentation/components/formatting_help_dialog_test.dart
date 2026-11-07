import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

Widget _opener() => Builder(
  builder: (context) => TextButton(
    onPressed: () => showFormattingHelp(context),
    child: const Text('Open'),
  ),
);

void main() {
  group('FormattingHelpDialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestMaterialApp(const Scaffold(body: FormattingHelpDialog())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders all 9 markdown formatting options with their syntax', (
      tester,
    ) async {
      await openDialog(tester);

      expect(find.text('Formatting help'), findsOneWidget);
      expect(
        find.text(
          'Type these markdown shortcuts directly in your message box:',
        ),
        findsOneWidget,
      );

      // Verify all 9 style names
      expect(find.text('Bold'), findsOneWidget);
      expect(find.text('Italic'), findsOneWidget);
      expect(find.text('Strikethrough'), findsOneWidget);
      expect(find.text('Link'), findsOneWidget);
      expect(find.text('Inline code'), findsOneWidget);
      expect(find.text('Code block'), findsOneWidget);
      expect(find.text('Quote'), findsOneWidget);
      expect(find.text('Bullet list'), findsOneWidget);
      expect(find.text('Numbered list'), findsOneWidget);

      // Verify syntax indicators
      expect(find.text('**text**'), findsOneWidget);
      expect(find.text('*text*'), findsOneWidget);
      expect(find.text('~~text~~'), findsOneWidget);
      expect(find.text('[text](url)'), findsOneWidget);
      expect(find.text('`code`'), findsOneWidget);
      expect(find.text('```code```'), findsOneWidget);
      expect(find.text('> quote'), findsOneWidget);
      expect(find.text('- item'), findsOneWidget);
      expect(find.text('1. item'), findsWidgets);
    });

    testWidgets('clicking the close button dismisses the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestMaterialApp(Scaffold(body: _opener())));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(FormattingHelpDialog), findsOneWidget);

      await tester.tap(find.byKey(const Key('formatting_help_close_button')));
      await tester.pumpAndSettle();
      expect(find.byType(FormattingHelpDialog), findsNothing);
    });

    testWidgets('pressing Escape key dismisses the dialog', (tester) async {
      await tester.pumpWidget(buildTestMaterialApp(Scaffold(body: _opener())));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(FormattingHelpDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(FormattingHelpDialog), findsNothing);
    });

    testWidgets('clicking outside the dialog dismisses it', (tester) async {
      await tester.pumpWidget(buildTestMaterialApp(Scaffold(body: _opener())));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(FormattingHelpDialog), findsOneWidget);

      // Tap on modal barrier outside dialog
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(FormattingHelpDialog), findsNothing);
    });
  });
}
