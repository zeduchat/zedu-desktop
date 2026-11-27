import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  Finder row(String description) =>
      find.ancestor(of: find.text(description), matching: find.byType(Row));

  /// The key labels shown on the row for [description].
  List<String> keysFor(WidgetTester tester, String description) => tester
      .widgetList<Text>(
        find.descendant(
          of: row(description).first,
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data!)
      .where((label) => label != description)
      .toList();

  testWidgets('lists zoom, conversation switching and the emoji picker '
      '(#6343)', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    await tester.pumpWidget(
      buildTestMaterialApp(const KeyboardShortcutsDialog()),
    );

    expect(keysFor(tester, 'Zoom in'), ['Ctrl', '+']);
    expect(keysFor(tester, 'Zoom out'), ['Ctrl', '-']);
    expect(keysFor(tester, 'Reset zoom'), ['Ctrl', '0']);
    expect(keysFor(tester, 'Previous conversation'), ['Alt', 'Up']);
    expect(keysFor(tester, 'Next conversation'), ['Alt', 'Down']);
    // Once for direct messages and once for channels and group chats, which
    // share the same message box.
    expect(find.text('Emoji picker'), findsNWidgets(2));
    expect(keysFor(tester, 'Emoji picker'), ['Ctrl', 'Shift', 'E']);

    debugDefaultTargetPlatformOverride = null;
  });
}
