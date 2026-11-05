import 'dart:async';

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

void main() {
  group('ChatHistoryNotifier temporary message ids (Ziki #2545)', () {
    late _MockDmRepository repository;
    late ProviderContainer container;
    late ChatHistoryNotifier notifier;
    late List<Completer<String>> pending;

    setUp(() async {
      repository = _MockDmRepository();
      pending = [];
      when(
        () => repository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => <Map<String, dynamic>>[]);
      when(
        () => repository.sendMessage(
          any(),
          any(),
          media: any(named: 'media'),
          mentions: any(named: 'mentions'),
          isChannel: any(named: 'isChannel'),
        ),
      ).thenAnswer((_) {
        final completer = Completer<String>();
        pending.add(completer);
        return completer.future;
      });

      container = ProviderContainer(
        overrides: [
          dmRepositoryProvider.overrideWithValue(repository),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        ],
      );
      notifier = container
          .listen(chatHistoryProvider('ch-1'), (_, _) {})
          .read();
      await pumpEventQueue();
    });

    tearDown(() => container.dispose());

    test('a burst of sends gives every message its own id', () async {
      // Not awaited: all of them start within the same millisecond.
      for (var i = 0; i < 20; i++) {
        unawaited(notifier.sendMessage('message $i'));
      }

      final ids = notifier.messages.map((m) => m['id']).toList();
      expect(ids, hasLength(20));
      expect(ids.toSet(), hasLength(20));

      for (final completer in pending) {
        completer.complete('thread');
      }
      await pumpEventQueue();
    });

    test('each send completes or fails against its own message', () async {
      final first = notifier.sendMessage('first');
      final second = notifier.sendMessage('second');

      pending[0].complete('thread-1');
      pending[1].completeError(Exception('network error'));
      await first;
      await second;

      final byContent = {for (final m in notifier.messages) m['content']: m};
      expect(byContent['first']!['status'], isNull);
      expect(byContent['first']!['thread_id'], 'thread-1');
      expect(byContent['second']!['status'], 'failed');
    });
  });
}
