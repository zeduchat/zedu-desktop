import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import 'package:zedu/features/dms/presentation/components/composer/mention_suggestion_list.dart';
import '../../../../../helpers/helpers.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class MockSecureStorageService extends Mock implements SecureStorageService {}

Widget buildComposerUnderTest() {
  final storage = MockSecureStorageService();
  when(() => storage.readData(any())).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(FakeAuthNotifier.new),
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(storage, userId: 'u', orgId: 'o'),
      ),
    ],
    child: buildTestMaterialApp(
      Scaffold(
        body: DmMessageComposer(
          recipientName: 'Team',
          channelId: 'channel-1',
          participants: [
            DmParticipant(
              userId: 'user-1',
              username: 'ada',
              email: 'ada@example.com',
            ),
            DmParticipant(
              userId: 'user-2',
              username: 'adaeze',
              email: 'adaeze@example.com',
            ),
            DmParticipant(
              userId: 'user-3',
              username: 'adam',
              email: 'adam@example.com',
            ),
          ],
        ),
      ),
    ),
  );
}

TextEditingController composerController(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller;

Future<void> typeMention(WidgetTester tester) async {
  await tester.pumpWidget(buildComposerUnderTest());
  await tester.tap(find.byType(TextField));
  await tester.enterText(find.byType(TextField), 'hi @ad');
  await tester.pump();
  expect(find.byType(MentionSuggestionList), findsOneWidget);
}

void main() {
  group('DmMessageComposer @mention keyboard navigation (Ziki #3437)', () {
    testWidgets('Down then Enter inserts the second person', (tester) async {
      await typeMention(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(composerController(tester).text, 'hi @adaeze ');
      expect(find.byType(MentionSuggestionList), findsNothing);
    });

    testWidgets('Up from the first person wraps to the last', (tester) async {
      await typeMention(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(composerController(tester).text, 'hi @adam ');
    });

    testWidgets('Down past the last person wraps to the first', (tester) async {
      await typeMention(tester);

      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(composerController(tester).text, 'hi @ada ');
    });

    testWidgets('Tab inserts the highlighted person', (tester) async {
      await typeMention(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(composerController(tester).text, 'hi @adaeze ');
    });

    testWidgets('the highlighted row is marked selected', (tester) async {
      final handle = tester.ensureSemantics();
      await typeMention(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Mention @adaeze')),
        matchesSemantics(
          label: 'Mention @adaeze',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester
            .widget<MentionSuggestionList>(find.byType(MentionSuggestionList))
            .selectedIndex,
        1,
      );
      handle.dispose();
    });

    testWidgets('typing more letters starts the highlight from the top', (
      tester,
    ) async {
      await typeMention(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hi @adae');
      await tester.pump();

      expect(
        tester
            .widget<MentionSuggestionList>(find.byType(MentionSuggestionList))
            .selectedIndex,
        0,
      );
    });
  });
}
