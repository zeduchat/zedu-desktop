import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  testWidgets('shows its tooltip and exposes it as the accessible label', (
    tester,
  ) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: Center(
            child: SquareIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit account',
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Edit account'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(SquareIconButton)),
      matchesSemantics(
        label: 'Edit account',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(find.byType(SquareIconButton));
    expect(taps, 1);
    semantics.dispose();
  });
}
