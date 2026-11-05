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

Map<String, dynamic> _message(int n) => {
  'id': 'm$n',
  'content': 'message $n',
  'user_id': 'user-2',
};

void main() {
  testWidgets('load more does not show a message a second time', (
    tester,
  ) async {
    final size = DmRepository.pageSize;
    final repo = _MockDmRepository();
    // Newest first: m1 is the newest. Page 1 is m1..m<size>.
    var firstPage = [for (var i = 1; i <= size; i++) _message(i)];
    when(() => repo.getMessages(any(), page: any(named: 'page'))).thenAnswer((
      invocation,
    ) async {
      final page = invocation.namedArguments[#page] as int;
      if (page == 1) return firstPage;
      // Page 2 as the server cuts it after one new message arrived: it starts
      // at the message that moved down from page 1.
      return [for (var i = size; i < size * 2; i++) _message(i)];
    });

    final container = ProviderContainer(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repo),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      ],
    );
    final sub = container.listen(chatHistoryProvider('ch-1'), (_, _) {});
    final notifier = sub.read();
    await tester.pump();
    expect(notifier.messages, hasLength(size));

    // A new message arrives and the poll adds it on top.
    firstPage = [
      {'id': 'new', 'content': 'brand new', 'user_id': 'user-2'},
      for (var i = 1; i < size; i++) _message(i),
    ];
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    expect(notifier.messages, hasLength(size + 1));

    await notifier.loadMore();

    final ids = notifier.messages.map((m) => m['id']).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'no id appears twice');
    expect(ids, hasLength(size + 1 + (size - 1)));

    sub.close();
    container.dispose();
  });
}
