import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

void main() {
  group('DmListTile active state indicator', () {
    late DmConversation conversation1;
    late DmConversation conversation2;

    setUp(() {
      conversation1 = DmConversation(
        channelId: 'dm-channel-1',
        username: 'alice',
        participantId: 'user-1',
        previewMessage: 'Hello there!',
        unreadCount: 0,
      );

      conversation2 = DmConversation(
        channelId: 'dm-channel-2',
        username: 'bob',
        participantId: 'user-2',
        previewMessage: 'How are you?',
        unreadCount: 2,
      );
    });

    Widget buildTestWidget({
      required DmConversation conversation,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: Scaffold(body: DmListTile(conversation: conversation)),
        ),
      );
    }

    testWidgets('unselected DM tile has transparent background and indicator', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(conversation: conversation1));
      await tester.pump();

      // Find the inner container with decoration
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(InkWell),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.transparent);

      final border = decoration.border as Border;
      expect(border.left.color, Colors.transparent);
      expect(border.left.width, 3.5);
    });

    testWidgets(
      'selected DM tile displays persistent active highlight and accent indicator',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            conversation: conversation1,
            overrides: [
              selectedDmProvider.overrideWith(() {
                final notifier = SelectedDmNotifier();
                notifier.select(conversation1);
                return notifier;
              }),
            ],
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(DmListTile));
        final colors = context.colors;

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(InkWell),
                matching: find.byType(Container),
              )
              .first,
        );

        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, colors.onPrimary.withValues(alpha: 0.16));

        final border = decoration.border as Border;
        expect(border.left.color, colors.accent);
        expect(border.left.width, 3.5);
      },
    );

    testWidgets(
      'tapping DM tile selects it in selectedDmProvider and activeChatProvider',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    DmListTile(conversation: conversation1),
                    DmListTile(conversation: conversation2),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(container.read(selectedDmProvider), isNull);

        // Tap first tile
        await tester.tap(find.text('alice'));
        await tester.pump();

        expect(container.read(selectedDmProvider)?.channelId, 'dm-channel-1');
        expect(
          container.read(activeChatProvider).type,
          ActiveChatType.directMessage,
        );
        expect(container.read(activeChatProvider).id, 'user-1');

        // Tap second tile
        await tester.tap(find.text('bob'));
        await tester.pump();

        expect(container.read(selectedDmProvider)?.channelId, 'dm-channel-2');
        expect(
          container.read(activeChatProvider).type,
          ActiveChatType.directMessage,
        );
        expect(container.read(activeChatProvider).id, 'user-2');
      },
    );
  });
}
