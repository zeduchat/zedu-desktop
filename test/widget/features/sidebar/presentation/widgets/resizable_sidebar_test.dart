import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/sidebar/presentation/widgets/resizable_sidebar.dart';

void main() {
  group('ResizableSidebar didUpdateWidget (#2573)', () {
    testWidgets('re-clamps width when parent maxWidth decreases below current width',
        (tester) async {
      double minWidth = 200;
      double maxWidth = 400;
      double initialWidth = 350;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: ResizableSidebar(
                  initialWidth: initialWidth,
                  minWidth: minWidth,
                  maxWidth: maxWidth,
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      );

      final initialSizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('resizable-sidebar')),
      );
      expect(initialSizedBox.width, 350);

      // Rebuild with reduced maxWidth
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResizableSidebar(
              initialWidth: initialWidth,
              minWidth: 200,
              maxWidth: 300,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      final updatedSizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('resizable-sidebar')),
      );
      expect(updatedSizedBox.width, 300);
    });

    testWidgets('re-clamps width when parent minWidth increases above current width',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResizableSidebar(
              initialWidth: 220,
              minWidth: 200,
              maxWidth: 400,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final initialSizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('resizable-sidebar')),
      );
      expect(initialSizedBox.width, 220);

      // Rebuild with increased minWidth
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResizableSidebar(
              initialWidth: 220,
              minWidth: 280,
              maxWidth: 400,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final updatedSizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('resizable-sidebar')),
      );
      expect(updatedSizedBox.width, 280);
    });

    testWidgets('retains width when new bounds still contain current width',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResizableSidebar(
              initialWidth: 300,
              minWidth: 200,
              maxWidth: 400,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final initialSizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('resizable-sidebar')),
      );
      expect(initialSizedBox.width, 300);

      // Rebuild with modified bounds that still contain 300
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResizableSidebar(
              initialWidth: 300,
              minWidth: 250,
              maxWidth: 350,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final updatedSizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('resizable-sidebar')),
      );
      expect(updatedSizedBox.width, 300);
    });
  });
}
