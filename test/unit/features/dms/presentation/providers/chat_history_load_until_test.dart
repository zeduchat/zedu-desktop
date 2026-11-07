import '../../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockDmRepository extends Mock implements DmRepository {}

class _SignedOutAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

/// #3438: a search hit far back in the history loads older pages until its
/// message is present, and stops there.
void main() {
  late MockDmRepository repository;
  late ProviderContainer container;

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

  List<Map<String, dynamic>> page(String prefix, int count) => List.generate(
    count,
    (i) => {'id': '$prefix-$i', 'content': 'x', 'user_id': 'u1'},
  );

  test('loads older pages until the message is present, then stops', () async {
    final pages = <int, List<Map<String, dynamic>>>{
      1: page('p1', DmRepository.pageSize),
      2: [
        ...page('p2', DmRepository.pageSize - 1),
        {'id': 'target', 'content': 'budget', 'user_id': 'u1'},
      ],
      3: page('p3', DmRepository.pageSize),
    };
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((call) async => pages[call.namedArguments[#page]] ?? []);

    final notifier = open();
    await Future<void>.delayed(Duration.zero);
    final found = await notifier.loadUntilMessage('target');

    expect(found, isTrue);
    expect(notifier.messages.map((m) => m['id']), contains('target'));
    verifyNever(() => repository.getMessages(any(), page: 3));
  });

  test('returns false when the history ends without the message', () async {
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((call) async {
      final p = call.namedArguments[#page] as int;
      return p == 1
          ? page('p1', DmRepository.pageSize)
          : <Map<String, dynamic>>[];
    });

    final notifier = open();
    await Future<void>.delayed(Duration.zero);
    final found = await notifier.loadUntilMessage('missing');

    expect(found, isFalse);
    expect(notifier.hasMore, isFalse);
  });

  test('does not load again when the message is already present', () async {
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer(
      (_) async => [
        {'id': 'target', 'content': 'budget', 'user_id': 'u1'},
      ],
    );

    final notifier = open();
    await Future<void>.delayed(Duration.zero);
    final requestsBefore = notifier.page;
    final found = await notifier.loadUntilMessage('target');

    expect(found, isTrue);
    expect(notifier.page, requestsBefore);
  });
}
