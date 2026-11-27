import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  group('DmEmojiPicker search (Ziki #3444)', () {
    late List<String> picked;
    late ProviderContainer container;

    final searchField = find.byKey(const ValueKey('emoji-search-field'));

    Future<void> pumpPicker(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(
            Scaffold(
              body: Center(
                child: DmEmojiPicker(
                  onEmojiSelected: picked.add,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    setUp(() {
      picked = [];
      container = ProviderContainer();
    });
    tearDown(() => container.dispose());

    int gridCount(WidgetTester tester) {
      final grid = tester.widget<GridView>(find.byType(GridView));
      return (grid.childrenDelegate as SliverChildBuilderDelegate).childCount!;
    }

    testWidgets('shows a search field that has focus', (tester) async {
      await pumpPicker(tester);

      expect(searchField, findsOneWidget);
      expect(find.text('Search emoji'), findsOneWidget);
      final field = tester.widget<TextField>(searchField);
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('a keyword shows only the matching emojis', (tester) async {
      await pumpPicker(tester);

      await tester.enterText(searchField, 'heart');
      await tester.pump();

      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('💙'), findsOneWidget);
      expect(find.text('😍'), findsOneWidget);
      expect(find.text('🚀'), findsNothing);
      expect(find.text('👍'), findsNothing);
    });

    testWidgets('every word of the query must match', (tester) async {
      await pumpPicker(tester);

      await tester.enterText(searchField, 'red heart');
      await tester.pump();

      expect(gridCount(tester), 1);
      expect(find.text('❤️'), findsOneWidget);
    });

    testWidgets('a query with no match shows the no-match state', (
      tester,
    ) async {
      await pumpPicker(tester);

      await tester.enterText(searchField, 'zzz');
      await tester.pump();

      expect(find.text('No emoji found'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('clearing the query restores the full grid', (tester) async {
      container.read(recentEmojisProvider.notifier).add('🚀');
      await pumpPicker(tester);
      final fullCount = gridCount(tester);

      await tester.enterText(searchField, 'rocket');
      await tester.pump();
      expect(gridCount(tester), 1);
      expect(find.text('Recently used'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pump();
      expect(gridCount(tester), fullCount);
      expect(fullCount, 80);
      expect(find.text('Recently used'), findsOneWidget);
      expect(find.text('No emoji found'), findsNothing);
    });

    testWidgets('Enter in the search field picks the first match', (
      tester,
    ) async {
      await pumpPicker(tester);

      await tester.enterText(searchField, 'rocket');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      expect(picked, ['🚀']);
    });

    testWidgets('arrow keys move the selection through the matches', (
      tester,
    ) async {
      await pumpPicker(tester);

      await tester.enterText(searchField, 'heart');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      // 😍 and 🥰 come first in the grid order, so the second match is 🥰.
      expect(picked, ['🥰']);
    });

    testWidgets('space types into the search field', (tester) async {
      await pumpPicker(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(picked, isEmpty);
    });
  });
}
