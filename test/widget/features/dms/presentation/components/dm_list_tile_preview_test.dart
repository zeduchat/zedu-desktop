import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';
import 'dm_list_tile_test.dart' show buildConversation, buildTileUnderTest;

void main() {
  group('DmListTile.previewText', () {
    test('drops the tags a message from Zedu web arrives with', () {
      expect(DmListTile.previewText('<p>hello</p>'), 'hello');
      expect(
        DmListTile.previewText('<p>hi <strong>Ada</strong></p><p>bye</p>'),
        'hi Ada bye',
      );
    });

    test('decodes entities and leaves plain text alone', () {
      expect(
        DmListTile.previewText('Tom &amp; Jerry&nbsp;&lt;3'),
        'Tom & Jerry <3',
      );
      expect(
        DmListTile.previewText('See you at standup'),
        'See you at standup',
      );
    });
  });

  testWidgets('the DM row shows the words of an HTML preview', (tester) async {
    await tester.pumpWidget(
      buildTileUnderTest(
        buildConversation(previewMessage: '<p>hello &amp; welcome</p>'),
      ),
    );

    expect(find.text('hello & welcome'), findsOneWidget);
    expect(find.textContaining('<p>'), findsNothing);
  });
}
