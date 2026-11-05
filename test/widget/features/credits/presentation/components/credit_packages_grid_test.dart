import 'package:zedu/features/credits/credits.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  group('CreditPackagesGrid responsive breakpoints logic', () {
    test('calculates 1 column for width < 680', () {
      expect(CreditPackagesGrid.getCrossAxisCount(400), 1);
      expect(CreditPackagesGrid.getCrossAxisCount(679.9), 1);
    });

    test('calculates 2 columns for 680 <= width < 1024', () {
      expect(CreditPackagesGrid.getCrossAxisCount(680), 2);
      expect(CreditPackagesGrid.getCrossAxisCount(800), 2);
      expect(CreditPackagesGrid.getCrossAxisCount(1023.9), 2);
    });

    test('calculates 3 columns for width >= 1024', () {
      expect(CreditPackagesGrid.getCrossAxisCount(1024), 3);
      expect(CreditPackagesGrid.getCrossAxisCount(1440), 3);
    });
  });

  group('CreditPackagesGrid responsive rendering', () {
    Future<void> pumpGridAtWidth(
      WidgetTester tester, {
      required double width,
      List<CreditPackage> packages = const [],
      void Function(CreditPackage)? onPurchase,
    }) async {
      tester.view.physicalSize = Size(width > 800 ? width + 100 : 800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: 1000,
                child: SingleChildScrollView(
                  child: CreditPackagesGrid(
                    packages: packages,
                    currentPlanSlug: 'free',
                    onPurchase: onPurchase ?? (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders 1 column when width is under 680', (tester) async {
      await pumpGridAtWidth(tester, width: 600);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 1);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
    });

    testWidgets('renders 2 columns when width is between 680 and 1024', (
      tester,
    ) async {
      await pumpGridAtWidth(tester, width: 850);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
    });

    testWidgets('renders 3 columns when width is 1024 or wider', (
      tester,
    ) async {
      await pumpGridAtWidth(tester, width: 1200);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
    });
  });
}
