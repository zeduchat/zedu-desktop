import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/theme/app_theme.dart';
import 'package:zedu/features/home/presentation/widgets/search_panel.dart';
import 'package:zedu/features/home/presentation/widgets/thread_panel.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  group('Desktop Panels Close Tooltip Tests', () {
    testWidgets('SearchPanel renders close search tooltip and handles tap', (
      tester,
    ) async {
      var closed = false;
      await tester.pumpWidget(
        _wrap(
          SearchPanel(
            onClose: () {
              closed = true;
            },
          ),
        ),
      );

      final closeButtonFinder = find.byTooltip('Close search');
      expect(closeButtonFinder, findsOneWidget);

      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });

    testWidgets('ThreadPanel renders close thread tooltip and handles tap', (
      tester,
    ) async {
      var closed = false;
      await tester.pumpWidget(
        _wrap(
          ThreadPanel(
            parentMessage: 'Hello team',
            parentAuthor: 'Sarah',
            onClose: () {
              closed = true;
            },
          ),
        ),
      );

      final closeButtonFinder = find.byTooltip('Close thread');
      expect(closeButtonFinder, findsOneWidget);

      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });
  });
}
