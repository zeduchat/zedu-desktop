import 'dart:math';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );
}

class _FakePeopleRepository implements PeopleRepository {
  _FakePeopleRepository({this.fail = false});

  final bool fail;
  final searches = <String>[];

  static const _everyone = [
    OrgMember(
      id: 'u-1',
      name: 'Ada Lovelace',
      email: 'ada@zedu.test',
      phone: '+234 800',
      online: true,
    ),
    OrgMember(id: 'u-2', name: 'Grace Hopper', email: 'grace@zedu.test'),
  ];

  @override
  Future<Result<MembersPage>> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  }) async {
    searches.add(search);
    if (fail) return const Failure(ApiFailure(message: 'offline'));
    final members = _everyone
        .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return Success(
      MembersPage(
        members: members,
        totalPages: search.isEmpty ? 2 : 1,
        totalItems: search.isEmpty ? 60 : members.length,
      ),
    );
  }
}

Future<MockDmRepository> _pump(
  WidgetTester tester,
  _FakePeopleRepository people, {
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final dms = MockDmRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        peopleRepositoryProvider.overrideWithValue(people),
        dmRepositoryProvider.overrideWithValue(dms),
      ],
      child: buildTestMaterialApp(
        Theme(
          data: theme ?? AppTheme.light,
          child: const Scaffold(
            body: Row(
              children: [
                PeopleSidebar(),
                Expanded(child: PeopleView()),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return dms;
}

void main() {
  testWidgets('lists the members in the sidebar and as cards', (tester) async {
    await _pump(tester, _FakePeopleRepository());

    expect(find.text('People'), findsOneWidget);
    expect(find.text('Invite People'), findsOneWidget);
    expect(find.text('New Chat'), findsOneWidget);
    expect(find.text('Channels'), findsNothing);
    // Each member is in the sidebar and on a card.
    expect(find.text('Ada Lovelace'), findsNWidgets(2));
    expect(find.text('ada@zedu.test'), findsOneWidget);
    expect(find.text('+234 800'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Showing 2 of 60 members'), findsOneWidget);
    // In the sidebar and under the cards.
    expect(find.text('Load more'), findsNWidgets(2));
  });

  testWidgets('searching for people asks the server', (tester) async {
    final people = _FakePeopleRepository();
    await _pump(tester, people);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search for people'),
      'grace',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(people.searches, contains('grace'));
    expect(find.text('Showing 1 of 1 member'), findsOneWidget);
    // The sidebar keeps its own list.
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('a search with no match says so', (tester) async {
    await _pump(tester, _FakePeopleRepository());

    await tester.enterText(
      find.widgetWithText(TextField, 'Search for people'),
      'zzz',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('No members found matching your search.'), findsOneWidget);
  });

  testWidgets('clicking a member opens the DM with them', (tester) async {
    final dms = await _pump(tester, _FakePeopleRepository());
    when(
      () => dms.openConversation(orgId: 'org-1', participantId: 'u-2'),
    ).thenAnswer((_) async => (channelId: 'c-2', participantId: 'u-2'));

    await tester.tap(find.text('Grace Hopper').first);
    await tester.pumpAndSettle();

    verify(
      () => dms.openConversation(orgId: 'org-1', participantId: 'u-2'),
    ).called(1);
  });

  testWidgets('shows a retry when members fail to load', (tester) async {
    await _pump(tester, _FakePeopleRepository(fail: true));

    expect(find.text('Could not load people'), findsOneWidget);
    expect(find.text('Could not load members.'), findsOneWidget);
    expect(find.text('Retry'), findsNWidgets(2));
  });

  for (final (name, theme, palette) in [
    ('light', AppTheme.light, AppPalette.light),
    ('dark', AppTheme.dark, AppPalette.dark),
  ]) {
    testWidgets('page and member cards use the $name background', (
      tester,
    ) async {
      await _pump(tester, _FakePeopleRepository(), theme: theme);

      final page = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PeopleView),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(page.color, palette.background);

      final cardName = find.text('Grace Hopper').last;
      final card = tester.widget<Material>(
        find.ancestor(of: cardName, matching: find.byType(Material)).first,
      );
      expect(card.color, palette.background);

      final nameColor = tester.widget<Text>(cardName).style!.color!;
      expect(nameColor, palette.textPrimary);
      expect(_contrast(nameColor, card.color!), greaterThanOrEqualTo(4.5));
      final status = tester.widget<Text>(find.text('Offline')).style!.color!;
      expect(_contrast(status, card.color!), greaterThanOrEqualTo(4.5));
    });
  }
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}
