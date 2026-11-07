import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockApiBaseService extends Mock implements ApiBaseService {}

/// A thread with no replies, so the panel loads without a server.
class _EmptyThreadRepository extends DmRepository {
  _EmptyThreadRepository() : super(_MockApiBaseService());

  @override
  Future<List<Map<String, dynamic>>> getThreadReplies({
    required String channelId,
    required String threadId,
  }) async => const [];
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      dmRepositoryProvider.overrideWithValue(_EmptyThreadRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
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
            channelId: 'chat-1',
            threadId: 'thread-1',
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
