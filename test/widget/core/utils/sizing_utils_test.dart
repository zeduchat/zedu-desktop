import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('MediaQueryValues._scale', () {
    Future<void> pumpWithWidth(WidgetTester tester, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 800)),
            child: Builder(
              builder: (context) => Text(context.s(100).toString()),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('clamps to 0.75 on narrow windows', (tester) async {
      await pumpWithWidth(tester, 600);
      expect(find.text('75.0'), findsOneWidget);
    });

    testWidgets('scales proportionally at mid widths', (tester) async {
      await pumpWithWidth(tester, 1080);
      expect(find.text('75.0'), findsOneWidget);
    });

    testWidgets('is 1.0 at the design width', (tester) async {
      await pumpWithWidth(tester, 1440);
      expect(find.text('100.0'), findsOneWidget);
    });

    testWidgets('stays 1.0 on wider windows', (tester) async {
      await pumpWithWidth(tester, 2000);
      expect(find.text('100.0'), findsOneWidget);
    });
  });
}
