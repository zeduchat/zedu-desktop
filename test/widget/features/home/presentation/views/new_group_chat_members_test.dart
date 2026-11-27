import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'me',
      firstName: 'Me',
      lastName: 'Myself',
      email: 'me@zedu.test',
      phone: '',
      username: 'me',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026, 1, 1),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'org-1',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

/// 30 members over two pages of 15, yourself on page 1. A search matches
/// name or email on one page.
class _PagedPeopleRepository implements PeopleRepository {
  final requests = <({int page, String search})>[];

  /// When set, the next request waits for it.
  Completer<void>? hold;

  static final everyone = [
    const OrgMember(id: 'me', name: 'Me Myself', email: 'me@zedu.test'),
    for (var i = 1; i < 30; i++)
      OrgMember(id: 'u$i', name: 'Member $i', email: 'member$i@zedu.test'),
  ];

  @override
  Future<Result<MembersPage>> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  }) async {
    requests.add((page: page, search: search));
    final held = hold;
    if (held != null) await held.future;
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      return Success(
        MembersPage(
          members: [
            for (final m in everyone)
              if (m.name.toLowerCase().contains(q) ||
                  m.email.toLowerCase().contains(q))
                m,
          ],
        ),
      );
    }
    return Success(
      MembersPage(
        members: everyone.skip((page - 1) * 15).take(15).toList(),
        currentPage: page,
        totalPages: 2,
        totalItems: everyone.length,
      ),
    );
  }
}

Future<void> _pumpView(WidgetTester tester, PeopleRepository people) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // Settings' team member list is deliberately not overridden: the page
  // loads its own members.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        peopleRepositoryProvider.overrideWithValue(people),
      ],
      child: buildTestMaterialApp(const Scaffold(body: NewGroupChatView())),
    ),
  );
}

Finder get _field => find.byType(TextField).first;

void main() {
  testWidgets('lists members without yourself and loads page 2 on scroll', (
    tester,
  ) async {
    final people = _PagedPeopleRepository();
    await _pumpView(tester, people);
    await tester.tap(_field);
    await tester.pumpAndSettle();

    expect(people.requests.first, (page: 1, search: ''));
    expect(find.text('member1@zedu.test'), findsOneWidget);
    expect(find.text('me@zedu.test'), findsNothing);

    await tester.dragUntilVisible(
      find.text('member20@zedu.test'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(people.requests, contains((page: 2, search: '')));
    expect(find.text('member20@zedu.test'), findsOneWidget);
  });

  testWidgets('typing searches the server by name or email', (tester) async {
    final people = _PagedPeopleRepository();
    await _pumpView(tester, people);
    await tester.tap(_field);
    await tester.pumpAndSettle();

    await tester.enterText(_field, 'member27@');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(people.requests.last, (page: 1, search: 'member27@'));
    expect(find.text('Member 27'), findsOneWidget);
    expect(find.text('Member 1'), findsNothing);
  });

  testWidgets('a search matching nobody says No members found', (tester) async {
    await _pumpView(tester, _PagedPeopleRepository());
    await tester.tap(_field);
    await tester.pumpAndSettle();

    await tester.enterText(_field, 'nobody-by-this-name');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('No members found'), findsOneWidget);
  });

  testWidgets('shows a loading row while members load', (tester) async {
    final people = _PagedPeopleRepository()..hold = Completer<void>();
    await _pumpView(tester, people);
    await tester.tap(_field);
    await tester.pump();

    expect(find.text('Loading members...'), findsOneWidget);

    people.hold!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Loading members...'), findsNothing);
    expect(find.text('member1@zedu.test'), findsOneWidget);
  });

  testWidgets('a selected member is no longer suggested', (tester) async {
    await _pumpView(tester, _PagedPeopleRepository());
    await tester.tap(_field);
    await tester.pumpAndSettle();

    await tester.tap(find.text('member1@zedu.test'));
    await tester.pumpAndSettle();
    await tester.tap(_field);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'Member 1'), findsOneWidget);
    expect(find.text('member1@zedu.test'), findsNothing);
    expect(find.text('member2@zedu.test'), findsOneWidget);
  });
}
