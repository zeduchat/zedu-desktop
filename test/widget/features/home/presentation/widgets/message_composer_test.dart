import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeProfileNotifier extends UserProfileNotifier {
  _FakeProfileNotifier(this.initial);

  final UserProfileState initial;

  @override
  UserProfileState build() => initial;
}

const _rocket = TeamMember(
  id: 'u-1',
  email: 'rocket@zedu.test',
  role: 'Member',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
  name: '🚀 Rocket',
);

const _engineer = TeamMember(
  id: 'u-2',
  email: 'alice@zedu.test',
  role: 'Member',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
  name: '👩‍💻 Alice',
);

const _blankName = TeamMember(
  id: 'u-3',
  email: 'blank@zedu.test',
  role: 'Member',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
  name: '   ',
);

const _ada = TeamMember(
  id: 'u-4',
  email: 'ada@zedu.test',
  role: 'Admin',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
  name: 'Ada Lovelace',
);

Future<void> _pumpWithMentionList(
  WidgetTester tester,
  List<TeamMember> members,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileNotifierProvider.overrideWith(
          () => _FakeProfileNotifier(UserProfileState(teamMembers: members)),
        ),
      ],
      child: buildTestMaterialApp(
        Scaffold(
          body: MessageComposer(
            activeChat: const ActiveChatState(
              type: ActiveChatType.channel,
              id: 'general',
            ),
            onSend: (_) {},
          ),
        ),
      ),
    ),
  );
  // Let the focus change rebuild the composer first, or the typed text is lost.
  await tester.tap(find.byType(TextField));
  await tester.pump();
  await tester.enterText(find.byType(TextField), '@');
  await tester.pump();
}

void main() {
  group('MessageComposer mention suggestion avatars', () {
    testWidgets('show the whole first emoji for emoji-prefixed names', (
      tester,
    ) async {
      await _pumpWithMentionList(tester, [_rocket, _engineer]);

      // Whole grapheme clusters, not half a surrogate pair.
      expect(find.text('🚀'), findsOneWidget);
      expect(find.text('👩‍💻'), findsOneWidget);
      expect(find.text('🚀 Rocket'), findsOneWidget);
    });

    testWidgets('fall back to ? for whitespace-only names', (tester) async {
      await _pumpWithMentionList(tester, [_blankName]);

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('keep showing the first letter of ordinary names', (
      tester,
    ) async {
      await _pumpWithMentionList(tester, [_ada]);

      expect(find.text('A'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });
  });
}
