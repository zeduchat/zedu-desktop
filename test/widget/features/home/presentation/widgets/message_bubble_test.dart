import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/theme/app_theme.dart';
import 'package:zedu/features/home/presentation/widgets/message_bubble.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('MessageBubble Author Initial Tests', () {
    testWidgets('renders standard author initial correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MessageBubble(
            author: 'Alice',
            text: 'Hello world',
            timestamp: '10:00 AM',
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets(
      'handles author name starting with emoji surrogate pair cleanly',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const MessageBubble(
              author: '🚀 Astro',
              text: 'Rocket test',
              timestamp: '10:05 AM',
            ),
          ),
        );

        expect(find.text('🚀'), findsOneWidget);
        expect(find.text('🚀 Astro'), findsOneWidget);
      },
    );

    testWidgets('trims leading whitespace from author name for initial', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MessageBubble(
            author: '   Bob',
            text: 'Indented author test',
            timestamp: '10:10 AM',
          ),
        ),
      );

      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('renders fallback question mark for empty or blank author', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MessageBubble(
            author: '   ',
            text: 'Blank author test',
            timestamp: '10:15 AM',
          ),
        ),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('renders (edited) indicator when isEdited is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const MessageBubble(
            author: 'Alice',
            text: 'Updated message',
            timestamp: '10:00 AM',
            isEdited: true,
          ),
        ),
      );

      expect(find.text('(edited)'), findsOneWidget);
    });

    testWidgets(
      'does not render (edited) indicator when isEdited is false or omitted',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const MessageBubble(
              author: 'Alice',
              text: 'Original message',
              timestamp: '10:00 AM',
            ),
          ),
        );

        expect(find.text('(edited)'), findsNothing);
      },
    );
  });

  group('MessageBubble reaction menu (#166)', () {
    testWidgets('opens next to the Add reaction button, not at a fixed spot', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: 400,
                height: 120,
                child: MessageBubble(
                  author: 'Alice',
                  text: 'Near the bottom',
                  timestamp: '10:20 AM',
                ),
              ),
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Near the bottom')));
      await tester.pump();

      final button = find.byIcon(Icons.add_reaction_outlined);
      expect(button, findsOneWidget);
      final buttonCenter = tester.getCenter(button);
      // The button sits near the bottom-right corner of the window.
      expect(buttonCenter.dx, greaterThan(800));
      expect(buttonCenter.dy, greaterThan(800));

      await tester.tap(button);
      await tester.pumpAndSettle();

      final menuItem = tester.getCenter(find.text('👍'));
      // The old code pinned the menu at (100, 100) in the top-left corner.
      // Now it opens beside the button, shifted up only to stay on screen.
      expect((menuItem.dx - buttonCenter.dx).abs(), lessThan(250));
      expect((menuItem.dy - buttonCenter.dy).abs(), lessThan(350));
    });
  });
}
