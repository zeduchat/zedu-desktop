import '../../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockDmRepository extends Mock implements DmRepository {}

class _SignedOutAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

/// #2680: "Jump to first unread" loads back past the last read time and finds
/// the oldest message sent after it.
void main() {
  late MockDmRepository repository;
  late ProviderContainer container;
  final lastReadAt = DateTime.utc(2026, 10, 17, 8);

  setUp(() {
    repository = MockDmRepository();
    container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_SignedOutAuth.new),
        dmRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() => container.dispose());

  ChatHistoryNotifier open() =>
      container.listen(chatHistoryProvider('ch-1'), (_, _) {}).read();

  Map<String, dynamic> at(String id, DateTime time) => {
    'id': id,
    'content': 'x',
    'user_id': 'u1',
    'created_at': time.toIso8601String(),
  };

  test('loads older pages until it passes the last read time', () async {
    final pages = <int, List<Map<String, dynamic>>>{
      1: [
        for (var i = 0; i < DmRepository.pageSize; i++)
          at('new-$i', lastReadAt.add(Duration(minutes: 100 - i))),
      ],
      2: [
        at('first-unread', lastReadAt.add(const Duration(minutes: 1))),
        at('read', lastReadAt.subtract(const Duration(minutes: 1))),
      ],
      3: [at('older', lastReadAt.subtract(const Duration(hours: 1)))],
    };
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((call) async => pages[call.namedArguments[#page]] ?? []);

    final notifier = open();
    await Future<void>.delayed(Duration.zero);

    expect(await notifier.loadUntilFirstUnread(lastReadAt), 'first-unread');
    verifyNever(() => repository.getMessages(any(), page: 3));
  });

  test('returns null when nothing arrived after the last read time', () async {
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer(
      (_) async => [at('read', lastReadAt.subtract(const Duration(hours: 1)))],
    );

    final notifier = open();
    await Future<void>.delayed(Duration.zero);

    expect(await notifier.loadUntilFirstUnread(lastReadAt), isNull);
  });
}
