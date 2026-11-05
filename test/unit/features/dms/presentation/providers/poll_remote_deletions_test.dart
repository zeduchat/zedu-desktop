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
  late _MockDmRepository repo;
  late List<Map<String, dynamic>> firstPage;

  setUp(() {
    repo = _MockDmRepository();
    when(() => repo.getMessages(any(), page: any(named: 'page'))).thenAnswer((
      invocation,
    ) async {
      final page = invocation.namedArguments[#page] as int;
      if (page == 1) return firstPage;
      return [for (var i = 21; i <= 40; i++) _message(i)];
    });
  });

  Future<(ProviderContainer, ChatHistoryNotifier, ProviderSubscription)> open(
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repo),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      ],
    );
    final sub = container.listen(chatHistoryProvider('ch-1'), (_, _) {});
    await tester.pump();
    return (container, sub.read(), sub);
  }

  Future<void> poll(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
  }

  List<String> ids(ChatHistoryNotifier n) =>
      n.messages.map((m) => m['id'].toString()).toList();

  testWidgets('a message someone else deleted disappears on the next poll', (
    tester,
  ) async {
    firstPage = [_message(3), _message(2), _message(1)];
    final (container, notifier, sub) = await open(tester);
    expect(ids(notifier), ['m3', 'm2', 'm1']);

    firstPage = [_message(3), _message(1)];
    await poll(tester);

    expect(ids(notifier), ['m3', 'm1']);

    sub.close();
    container.dispose();
  });

  testWidgets('older loaded messages are not judged by the newest page', (
    tester,
  ) async {
    firstPage = [for (var i = 1; i <= 20; i++) _message(i)];
    final (container, notifier, sub) = await open(tester);
    await notifier.loadMore();
    expect(notifier.messages, hasLength(40));

    // m5 is deleted, so the newest page now reaches m21.
    firstPage = [
      for (var i = 1; i <= 21; i++)
        if (i != 5) _message(i),
    ];
    await poll(tester);

    expect(ids(notifier), isNot(contains('m5')));
    // m22..m40 are older than the newest page and stay.
    expect(ids(notifier), containsAll(['m22', 'm30', 'm40']));
    expect(notifier.messages, hasLength(39));

    sub.close();
    container.dispose();
  });

  testWidgets('an empty answer does not wipe the list', (tester) async {
    firstPage = [_message(2), _message(1)];
    final (container, notifier, sub) = await open(tester);

    firstPage = [];
    await poll(tester);

    expect(ids(notifier), ['m2', 'm1']);

    sub.close();
    container.dispose();
  });

  testWidgets('a poll that lists everything changes nothing', (tester) async {
    firstPage = [_message(2), _message(1)];
    final (container, notifier, sub) = await open(tester);
    var notified = 0;
    notifier.addListener(() => notified++);

    await poll(tester);

    expect(ids(notifier), ['m2', 'm1']);
    expect(notified, 0);

    sub.close();
    container.dispose();
  });
}
