import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  testWidgets('draws the drag handle with the border token', (tester) async {
    await tester.pumpWidget(
      buildTestMaterialApp(
        const Scaffold(
          body: Row(children: [ResizableSidebar(child: SizedBox.expand())]),
        ),
      ),
    );

    final handle = tester.widget<Container>(
      find.byKey(const ValueKey('resizable-sidebar-handle-line')),
    );

    expect(handle.color, AppPalette.light.borderOutline);
  });

  testWidgets('reports the width while dragging and starts from initialWidth', (
    tester,
  ) async {
    final reported = <double>[];
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: Row(
            children: [
              ResizableSidebar(
                initialWidth: 260,
                onWidthChanged: reported.add,
                child: const SizedBox.expand(),
              ),
            ],
          ),
        ),
      ),
    );
    final sidebar = find.byKey(const ValueKey('resizable-sidebar'));
    expect(tester.getSize(sidebar).width, 260);

    await tester.drag(
      find.byKey(const ValueKey('resizable-sidebar-handle')),
      const Offset(40, 0),
    );
    await tester.pump();

    expect(reported, isNotEmpty);
    expect(reported.last, tester.getSize(sidebar).width);
    expect(reported.last, greaterThan(260));
  });
}
