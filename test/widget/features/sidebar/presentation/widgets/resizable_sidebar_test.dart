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
}
