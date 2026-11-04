import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

class _ToastTrigger extends StatefulWidget {
  const _ToastTrigger();

  @override
  State<_ToastTrigger> createState() => _ToastTriggerState();
}

class _ToastTriggerState extends State<_ToastTrigger> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: const Key('show_toast'),
      onPressed: () {
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: 'Something went wrong',
        );
      },
      child: const Text('Show toast'),
    );
  }
}

void main() {
  group('AppToast', () {
    testWidgets('close button has a Dismiss tooltip', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
          home: const Scaffold(body: _ToastTrigger()),
        ),
      );

      await tester.tap(find.byKey(const Key('show_toast')));
      await tester.pumpAndSettle();

      final tooltip = find.byType(Tooltip);
      expect(tooltip, findsOneWidget);
      final tooltipWidget = tester.widget<Tooltip>(tooltip.first);
      expect(tooltipWidget.message, 'Dismiss');
    });

    testWidgets('close button has Dismiss semantics label', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
          home: const Scaffold(body: _ToastTrigger()),
        ),
      );

      await tester.tap(find.byKey(const Key('show_toast')));
      await tester.pumpAndSettle();

      final semantics = find.bySemanticsLabel('Dismiss');
      expect(semantics, findsOneWidget);
    });

    testWidgets('close button uses click cursor', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
          home: const Scaffold(body: _ToastTrigger()),
        ),
      );

      await tester.tap(find.byKey(const Key('show_toast')));
      await tester.pumpAndSettle();

      final mouseRegions = find.byType(MouseRegion);
      expect(mouseRegions, findsWidgets);
      final clickCursorRegions = mouseRegions.evaluate().where((e) {
        final widget = e.widget as MouseRegion;
        return widget.cursor == SystemMouseCursors.click;
      });
      expect(clickCursorRegions, isNotEmpty);
    });
  });
}
