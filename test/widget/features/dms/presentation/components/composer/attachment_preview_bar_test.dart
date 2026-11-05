import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/presentation/components/composer/composer.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  Future<List<int>> pumpBar(WidgetTester tester) async {
    final removed = <int>[];
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: AttachmentPreviewBar(
            files: [XFile('first.pdf'), XFile('second.pdf')],
            onRemove: removed.add,
            colors: AppPalette.light,
          ),
        ),
      ),
    );
    return removed;
  }

  testWidgets('remove button has a tooltip and a click cursor', (tester) async {
    await pumpBar(tester);

    final button = find.byTooltip('Remove attachment');
    expect(button, findsNWidgets(2));

    final cursors = tester
        .widgetList<MouseRegion>(
          find.descendant(of: button.first, matching: find.byType(MouseRegion)),
        )
        .map((region) => region.cursor);
    expect(cursors, contains(SystemMouseCursors.click));
  });

  testWidgets('remove button can be clicked across its 24x24 target', (
    tester,
  ) async {
    final removed = await pumpBar(tester);

    final button = find.byTooltip('Remove attachment').first;
    expect(tester.getSize(button), const Size(24, 24));

    final corners = tester.getRect(button).deflate(1);
    for (final corner in [
      corners.topLeft,
      corners.topRight,
      corners.bottomLeft,
      corners.bottomRight,
    ]) {
      await tester.tapAt(corner);
    }

    expect(removed, [0, 0, 0, 0]);
  });
}
