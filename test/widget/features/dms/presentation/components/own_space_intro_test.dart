import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  Future<void> pumpIntro(WidgetTester tester, String name) async {
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: SingleChildScrollView(
            child: OwnSpaceIntro(
              conversation: DmConversation(
                channelId: 'dm-1',
                username: name,
                participantId: 'user-1',
                previewMessage: '',
                unreadCount: 0,
              ),
              onEditProfile: () {},
            ),
          ),
        ),
      ),
    );
  }

  String initialShown(WidgetTester tester) {
    final avatar = find.byType(CircleAvatar);
    final text = find.descendant(of: avatar, matching: find.byType(Text));
    return tester.widget<Text>(text).data!;
  }

  testWidgets('keeps an emoji whole when the name starts with one', (
    tester,
  ) async {
    await pumpIntro(tester, '\u{1F680} Jaylinka');
    expect(initialShown(tester), '\u{1F680}');
  });

  testWidgets('shows a plain initial in upper case', (tester) async {
    await pumpIntro(tester, '  ada');
    expect(initialShown(tester), 'A');
  });

  testWidgets('falls back to ? when the name is blank', (tester) async {
    await pumpIntro(tester, '   ');
    expect(initialShown(tester), '?');
  });
}
