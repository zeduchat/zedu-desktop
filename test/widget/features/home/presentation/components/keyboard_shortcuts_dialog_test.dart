import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

// The list must match the real bindings (Ziki #3439): channels and group
// chats use the DM composer, so plain Enter sends there too.
void main() {
  Future<void> pumpDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      buildTestMaterialApp(const Scaffold(body: KeyboardShortcutsDialog())),
    );
  }

  testWidgets('has one Messages section and no Cmd/Ctrl+Enter send row', (
    tester,
  ) async {
    await pumpDialog(tester);

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Channels and group chats'), findsNothing);
    expect(find.text('Direct messages'), findsNothing);
    // Only plain Enter sends.
    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets('lists the sidebar shortcut under Anywhere', (tester) async {
    await pumpDialog(tester);

    expect(find.text('Show or hide the sidebar'), findsOneWidget);
    expect(find.text('\\'), findsOneWidget);
  });
}
