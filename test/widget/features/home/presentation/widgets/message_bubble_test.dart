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

  group('MessageBubble reaction menu mounted check (#9088)', () {
    testWidgets(
      'hovering shows add-reaction button and selecting emoji adds reaction when mounted',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: MessageBubble(
                author: 'Alice',
                text: 'Reaction test',
                timestamp: '10:00 AM',
              ),
            ),
          ),
        );

        // Initially, add reaction button is not visible because not hovering
        expect(find.byIcon(Icons.add_reaction_outlined), findsNothing);

        // Hover over the MessageBubble to trigger _isHovering = true
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.byType(MessageBubble)));
        await tester.pump();

        expect(find.byIcon(Icons.add_reaction_outlined), findsOneWidget);

        // Tap add reaction button to open menu
        await tester.tap(find.byIcon(Icons.add_reaction_outlined));
        await tester.pumpAndSettle();

        // Menu is displayed with emojis
        expect(find.text('👍'), findsOneWidget);

        // Tap the 👍 emoji
        await tester.tap(find.text('👍'));
        await tester.pumpAndSettle();

        // Reaction is added to the bubble (emoji key and count)
        expect(find.text('👍'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets(
      'selecting an emoji does not throw if MessageBubble is disposed while menu is open',
      (tester) async {
        final key = GlobalKey();

        Widget buildHarness({required bool showBubble}) {
          return MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: showBubble
                  ? MessageBubble(
                      key: key,
                      author: 'Alice',
                      text: 'Disposal test',
                      timestamp: '10:00 AM',
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }

        await tester.pumpWidget(buildHarness(showBubble: true));

        // Hover to reveal add reaction button
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.byType(MessageBubble)));
        await tester.pump();

        expect(find.byIcon(Icons.add_reaction_outlined), findsOneWidget);

        // Tap to open popup menu
        await tester.tap(find.byIcon(Icons.add_reaction_outlined));
        await tester.pumpAndSettle();

        expect(find.text('❤️'), findsOneWidget);

        // Unmount the MessageBubble while popup menu remains open on Navigator
        await tester.pumpWidget(buildHarness(showBubble: false));
        await tester.pump();

        // MessageBubble is unmounted
        expect(find.byType(MessageBubble), findsNothing);
        // PopupMenuItem is still active in the Navigator overlay
        expect(find.text('❤️'), findsOneWidget);

        // Tap the emoji item on the open popup menu
        await tester.tap(find.text('❤️'));
        await tester.pumpAndSettle();

        // Ensure no unhandled exception (e.g. setState called after dispose) was thrown
        expect(tester.takeException(), isNull);
      },
    );
  });
}
