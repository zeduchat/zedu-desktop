import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

/// #3438: tapping a search result reports that hit to the chat.
void main() {
  testWidgets('tapping a result reports that hit', (tester) async {
    final repository = MockDmRepository();
    const hit = ConversationSearchHit(
      messageId: 'm1',
      text: 'budget review',
      userName: 'Ada Obi',
    );
    when(
      () => repository.searchMessages(
        channelId: any(named: 'channelId'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => [hit]);

    ConversationSearchHit? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dmRepositoryProvider.overrideWithValue(repository)],
        child: buildTestMaterialApp(
          Scaffold(
            body: SearchPanel(
              channelId: 'chat-1',
              onClose: () {},
              onResultSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'budget');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('budget review'));
    await tester.pump();

    expect(selected?.messageId, 'm1');
  });
}
