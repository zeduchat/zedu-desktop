import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: ThreadPanel(
            parentMessage: 'Parent message',
            parentAuthor: 'Ada',
            onClose: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('send icon submits and clears the reply field', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), '  Reply via icon  ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('Reply via icon'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('Enter submits and clears the reply field', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), 'Reply via keyboard');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Reply via keyboard'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('whitespace-only reply is not added', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('0 replies'), findsOneWidget);
  });
}
