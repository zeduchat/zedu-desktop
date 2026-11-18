import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

void main() {
  group('ThreadPanel Newest-First Ordering', () {
    Widget createTestWidget({bool initialNewestAtTop = true}) {
      return buildTestMaterialApp(
        Scaffold(
          body: ThreadPanel(
            parentAuthor: 'Jane Doe',
            parentMessage: 'Initial message for thread discussion',
            parentTimestamp: '10:00 AM',
            initialNewestAtTop: initialNewestAtTop,
            onClose: () {},
          ),
        ),
      );
    }

    testWidgets('shows replies with newest at top when enabled', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget(initialNewestAtTop: true));
      await tester.pumpAndSettle();

      final replyField = find.byType(TextField);
      final sendButton = find.byTooltip('Send reply');

      // Submit first reply
      await tester.enterText(replyField, 'First reply (older)');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Submit second reply
      await tester.enterText(replyField, 'Second reply (newer)');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(find.text('2 replies • Newest at top'), findsOneWidget);

      // Verify the newer reply appears before the older reply in the widget tree
      final newerFinder = find.text('Second reply (newer)');
      final olderFinder = find.text('First reply (older)');

      expect(newerFinder, findsOneWidget);
      expect(olderFinder, findsOneWidget);

      final newerY = tester.getTopLeft(newerFinder).dy;
      final olderY = tester.getTopLeft(olderFinder).dy;

      // Newer reply must be higher (smaller Y value) than older reply
      expect(newerY < olderY, isTrue);
    });

    testWidgets('toggles sort order between newest-at-top and oldest-first', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget(initialNewestAtTop: true));
      await tester.pumpAndSettle();

      final replyField = find.byType(TextField);
      final sendButton = find.byTooltip('Send reply');

      await tester.enterText(replyField, 'Reply Alpha');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      await tester.enterText(replyField, 'Reply Beta');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Tap order toggle button
      final toggleButton = find.byTooltip(
        'Newest replies at top (tap for oldest first)',
      );
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.text('2 replies • Oldest first'), findsOneWidget);

      final alphaY = tester.getTopLeft(find.text('Reply Alpha')).dy;
      final betaY = tester.getTopLeft(find.text('Reply Beta')).dy;

      // In oldest-first, Alpha must be higher than Beta
      expect(alphaY < betaY, isTrue);
    });
  });
}
