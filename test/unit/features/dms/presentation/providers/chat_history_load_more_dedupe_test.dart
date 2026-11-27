import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'org-slug',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

/// Messages m[from] down to m[to], newest first, as the server pages them.
List<Map<String, dynamic>> _range(int from, int to) => [
  for (var i = from; i >= to; i--)
    {
      'id': 'm$i',
      'user_id': 'user-1',
      'content': 'message $i',
      'created_at': DateTime.utc(2026, 1, 1).add(Duration(minutes: i + 100)),
    },
];

Future<List<String>> _loadAfterArrival(
  WidgetTester tester,
  List<Map<String, dynamic>> secondPage, {
  void Function(ChatHistoryNotifier)? check,
}) async {
  final repo = _MockDmRepository();
  var firstPageCalls = 0;
  when(() => repo.getMessages(any(), page: any(named: 'page'))).thenAnswer((
    invocation,
  ) async {
    final page = invocation.namedArguments[#page] as int;
    if (page == 2) return secondPage;
    firstPageCalls++;
    // The initial load sees m20..m1; m21 arrives before the first poll.
    return firstPageCalls == 1 ? _range(20, 1) : _range(21, 2);
  });

  final container = ProviderContainer(
    overrides: [
      dmRepositoryProvider.overrideWithValue(repo),
      authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
    ],
  );
  final sub = container.listen(chatHistoryProvider('ch-1'), (_, _) {});
  await tester.pump();

  final notifier = container.read(chatHistoryProvider('ch-1'));
  await tester.pump(const Duration(seconds: 10));
  expect(notifier.messages.first['id'], 'm21');

  await notifier.loadMore();
  check?.call(notifier);
  final ids = [for (final m in notifier.messages) m['id'] as String];
  // Stop the polling timer before the test ends.
  sub.close();
  container.dispose();
  return ids;
}

void main() {
  testWidgets('an older page that repeats a loaded message adds it once', (
    tester,
  ) async {
    // m1 was pushed onto page 2 by the arrival of m21.
    late ChatHistoryNotifier notifier;
    final ids = await _loadAfterArrival(
      tester,
      _range(1, -18),
      check: (n) => notifier = n,
    );

    expect(ids, hasLength(40));
    expect(ids.toSet(), hasLength(40));
    expect(ids.where((id) => id == 'm1'), hasLength(1));
    expect(ids, [for (var i = 21; i >= -18; i--) 'm$i']);
    // The server page was full, so there is still older history.
    expect(notifier.hasMore, isTrue);
    expect(notifier.page, 2);
  });

  testWidgets('a repeated id within one page is added once', (tester) async {
    final page = [..._range(0, -9), ..._range(-9, -18)];
    final ids = await _loadAfterArrival(tester, page);

    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, [for (var i = 21; i >= -18; i--) 'm$i']);
  });

  testWidgets('a page that does not overlap is appended in full', (
    tester,
  ) async {
    late ChatHistoryNotifier notifier;
    final ids = await _loadAfterArrival(
      tester,
      _range(0, -19),
      check: (n) => notifier = n,
    );

    expect(ids, hasLength(41));
    expect(ids, [for (var i = 21; i >= -19; i--) 'm$i']);
    expect(notifier.hasMore, isTrue);
  });
}
