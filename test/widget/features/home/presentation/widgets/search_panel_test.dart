import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  testWidgets('disposes its search controller when removed', (tester) async {
    await tester.pumpWidget(
      buildTestMaterialApp(Scaffold(body: SearchPanel(onClose: () {}))),
    );

    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    void listener() {}
    controller.addListener(listener);
    controller.removeListener(listener);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(() => controller.addListener(listener), throwsFlutterError);
  });
}
