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

Map<String, dynamic> _message({
  required String fileName,
  required String fileLink,
  String content = 'see the file',
}) => {
  'id': 'm1',
  'content': content,
  'user_id': 'user-2',
  'media': [
    {'file_name': fileName, 'file_link': fileLink},
  ],
};

void main() {
  late _MockDmRepository repo;
  late List<Map<String, dynamic>> server;

  setUp(() {
    repo = _MockDmRepository();
    when(
      () => repo.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => server);
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

  testWidgets('a poll shows the attachment a remote edit changed, once', (
    tester,
  ) async {
    server = [_message(fileName: 'old.png', fileLink: 'https://files/old.png')];
    final (container, notifier, sub) = await open(tester);
    expect(notifier.messages, hasLength(1));
    expect(notifier.messages.first['media'][0]['file_name'], 'old.png');

    // The same message comes back from the server with another file.
    server = [_message(fileName: 'new.png', fileLink: 'https://files/new.png')];
    await poll(tester);

    expect(notifier.messages, hasLength(1));
    final media = notifier.messages.first['media'] as List;
    expect(media.single['file_name'], 'new.png');
    expect(media.single['file_link'], 'https://files/new.png');

    sub.close();
    container.dispose();
  });

  testWidgets('a poll with the same attachment changes nothing', (
    tester,
  ) async {
    server = [_message(fileName: 'a.png', fileLink: 'https://files/a.png')];
    final (container, notifier, sub) = await open(tester);
    var notified = 0;
    notifier.addListener(() => notified++);

    await poll(tester);

    expect(notifier.messages, hasLength(1));
    expect(notified, 0);

    sub.close();
    container.dispose();
  });

  testWidgets('a remote edit changing text and attachment updates both', (
    tester,
  ) async {
    server = [_message(fileName: 'a.png', fileLink: 'https://files/a.png')];
    final (container, notifier, sub) = await open(tester);

    server = [
      _message(
        fileName: 'b.pdf',
        fileLink: 'https://files/b.pdf',
        content: 'see the new file',
      ),
    ];
    await poll(tester);

    expect(notifier.messages.first['content'], 'see the new file');
    expect(notifier.messages.first['media'][0]['file_name'], 'b.pdf');

    sub.close();
    container.dispose();
  });
}
