import 'dart:async';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockDmRepository extends Mock implements DmRepository {}

class _MemoryStorage extends Fake implements SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<String?> readData(String key) async => values[key];

  @override
  Future<void> writeData(String key, String value) async {
    values[key] = value;
  }
}

class _SignedOutAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

void main() {
  group('ChatHistoryNotifier polling', () {
    late MockDmRepository repository;

    List<Map<String, dynamic>> history(String content) => [
      {'id': 'm1', 'content': content, 'user_id': 'u1'},
    ];

    ChatHistoryNotifier open(ProviderContainer container) =>
        container.listen(chatHistoryProvider('ch-1'), (_, _) {}).read();

    setUp(() => repository = MockDmRepository());

    testWidgets('replaces the text of a message edited elsewhere', (
      tester,
    ) async {
      {
        final reads = [history('original'), history('corrected')];
        when(
          () => repository.getMessages(any(), page: any(named: 'page')),
        ).thenAnswer((_) async => reads.removeAt(0));
        final container = ProviderContainer(
          overrides: [
            authNotifierProvider.overrideWith(_SignedOutAuth.new),
            dmRepositoryProvider.overrideWithValue(repository),
          ],
        );
        final notifier = open(container);
        await tester.pump();
        expect(notifier.messages.single['content'], 'original');

        await tester.pump(const Duration(seconds: 10));
        await tester.pump();

        expect(notifier.messages, hasLength(1));
        expect(notifier.messages.single['id'], 'm1');
        expect(notifier.messages.single['content'], 'corrected');
        container.dispose();
      }
    });

    testWidgets('leaves the list alone when the response is unchanged', (
      tester,
    ) async {
      {
        when(
          () => repository.getMessages(any(), page: any(named: 'page')),
        ).thenAnswer((_) async => history('same'));
        final container = ProviderContainer(
          overrides: [
            authNotifierProvider.overrideWith(_SignedOutAuth.new),
            dmRepositoryProvider.overrideWithValue(repository),
          ],
        );
        final notifier = open(container);
        await tester.pump();
        var notified = 0;
        notifier.addListener(() => notified++);

        await tester.pump(const Duration(seconds: 10));
        await tester.pump();

        expect(notifier.messages.single['content'], 'same');
        expect(notified, 0);
        container.dispose();
      }
    });

    testWidgets(
      'still prepends new arrivals and updates edited text together',
      (tester) async {
        {
          final reads = [
            history('original'),
            [
              {'id': 'm2', 'content': 'new', 'user_id': 'me'},
              ...history('corrected'),
            ],
          ];
          when(
            () => repository.getMessages(any(), page: any(named: 'page')),
          ).thenAnswer((_) async => reads.removeAt(0));
          final container = ProviderContainer(
            overrides: [
              authNotifierProvider.overrideWith(_SignedOutAuth.new),
              dmRepositoryProvider.overrideWithValue(repository),
            ],
          );
          final notifier = open(container);
          await tester.pump();

          await tester.pump(const Duration(seconds: 10));
          await tester.pump();

          expect(notifier.messages.map((m) => m['id']), ['m2', 'm1']);
          expect(notifier.messages.last['content'], 'corrected');
          container.dispose();
        }
      },
    );

    testWidgets('does not overwrite an edit that is still being saved', (
      tester,
    ) async {
      {
        final reads = [history('original'), history('original')];
        when(
          () => repository.getMessages(any(), page: any(named: 'page')),
        ).thenAnswer((_) async => reads.removeAt(0));
        final saving = Completer<void>();
        when(
          () => repository.editMessage(
            any(),
            content: any(named: 'content'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer((_) => saving.future);
        final container = ProviderContainer(
          overrides: [
            authNotifierProvider.overrideWith(_SignedOutAuth.new),
            dmRepositoryProvider.overrideWithValue(repository),
          ],
        );
        final notifier = open(container);
        await tester.pump();

        unawaited(notifier.saveEdit('m1', 'my edit'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();

        expect(notifier.messages.single['content'], 'my edit');
        saving.complete();
        await tester.pump();
        container.dispose();
      }
    });
  });

  _deleteTests();
  _retryTests();
  _clearHistoryTests();
  _loadErrorTests();
  group('ChatHistoryNotifier.saveEdit', () {
    late MockDmRepository mockRepository;
    late ProviderContainer container;
    late ChatHistoryNotifier notifier;

    final initialMessages = <Map<String, dynamic>>[
      {'id': 'm1', 'content': 'hello', 'user_id': 'u1'},
    ];

    setUp(() async {
      mockRepository = MockDmRepository();
      when(
        () => mockRepository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => List<Map<String, dynamic>>.from(initialMessages),
      );

      container = ProviderContainer(
        overrides: [dmRepositoryProvider.overrideWithValue(mockRepository)],
      );
      notifier = container
          .listen(chatHistoryProvider('ch-1'), (_, _) {})
          .read();
      await pumpEventQueue();
    });

    tearDown(() {
      container.dispose();
    });

    test('names the edited message with its thread id', () async {
      notifier.messages = [
        {'id': 'local-1', 'thread_id': 't-1', 'content': 'hello'},
      ];
      when(
        () => mockRepository.editMessage(
          any(),
          content: any(named: 'content'),
          threadId: any(named: 'threadId'),
        ),
      ).thenAnswer((_) async {});

      await notifier.saveEdit('local-1', 'edited');

      verify(
        () => mockRepository.editMessage(
          any(),
          content: 'edited',
          threadId: 't-1',
        ),
      ).called(1);
    });

    test('falls back to the message id for a message from history', () async {
      when(
        () => mockRepository.editMessage(
          any(),
          content: any(named: 'content'),
          threadId: any(named: 'threadId'),
        ),
      ).thenAnswer((_) async {});

      await notifier.saveEdit('m1', 'edited');

      verify(
        () => mockRepository.editMessage(
          any(),
          content: 'edited',
          threadId: 'm1',
        ),
      ).called(1);
    });

    test('keeps the new content when the edit request succeeds', () async {
      when(
        () => mockRepository.editMessage(
          any(),
          content: any(named: 'content'),
          threadId: any(named: 'threadId'),
        ),
      ).thenAnswer((_) async {});

      notifier.startEditing('m1');
      final saved = await notifier.saveEdit('m1', 'edited');

      expect(saved, isTrue);
      expect(notifier.editingMessageId, isNull);
      expect(notifier.messages.single['content'], 'edited');
    });

    test(
      'reverts to the original content when the edit request fails',
      () async {
        when(
          () => mockRepository.editMessage(
            any(),
            content: any(named: 'content'),
            threadId: any(named: 'threadId'),
          ),
        ).thenThrow(Exception('network error'));

        notifier.startEditing('m1');
        final saved = await notifier.saveEdit('m1', 'edited');

        expect(saved, isFalse);
        expect(notifier.editingMessageId, isNull);
        expect(notifier.messages.single['content'], 'hello');
      },
    );

    test(
      'reverts to null content when the edited message had no content',
      () async {
        when(
          () => mockRepository.editMessage(
            any(),
            content: any(named: 'content'),
            threadId: any(named: 'threadId'),
          ),
        ).thenThrow(Exception('network error'));

        notifier.messages = [
          {'id': 'm1', 'content': null, 'user_id': 'u1'},
        ];

        notifier.startEditing('m1');
        await notifier.saveEdit('m1', 'edited');

        expect(notifier.editingMessageId, isNull);
        expect(notifier.messages.single['content'], isNull);
      },
    );

    test(
      'keeps the newer edit when an older pending edit fails later',
      () async {
        final firstRequest = Completer<void>();
        var callCount = 0;
        when(
          () => mockRepository.editMessage(
            any(),
            content: any(named: 'content'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer((_) {
          callCount++;
          if (callCount == 1) return firstRequest.future;
          return Future.value();
        });

        notifier.startEditing('m1');
        final first = notifier.saveEdit('m1', 'edited1');
        notifier.startEditing('m1');
        final second = notifier.saveEdit('m1', 'edited2');

        firstRequest.completeError(Exception('network error'));
        await second;
        await first;

        expect(notifier.messages.single['content'], 'edited2');
      },
    );

    test(
      'keeps the newer save when an older edit with the same content fails',
      () async {
        final firstRequest = Completer<void>();
        var callCount = 0;
        when(
          () => mockRepository.editMessage(
            any(),
            content: any(named: 'content'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer((_) {
          callCount++;
          if (callCount == 1) return firstRequest.future;
          return Future.value();
        });

        notifier.startEditing('m1');
        final first = notifier.saveEdit('m1', 'edited');
        notifier.startEditing('m1');
        final second = notifier.saveEdit('m1', 'edited');

        firstRequest.completeError(Exception('network error'));
        await second;
        await first;

        expect(notifier.messages.single['content'], 'edited');
      },
    );

    test(
      'keeps another message being edited when a queued save starts',
      () async {
        final firstRequest = Completer<void>();
        var callCount = 0;
        when(
          () => mockRepository.editMessage(
            any(),
            content: any(named: 'content'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer((_) {
          callCount++;
          if (callCount == 1) return firstRequest.future;
          return Future.value();
        });

        notifier.messages = [
          {'id': 'm1', 'content': 'hello', 'user_id': 'u1'},
          {'id': 'm2', 'content': 'other', 'user_id': 'u1'},
        ];

        notifier.startEditing('m1');
        final first = notifier.saveEdit('m1', 'edited1');
        notifier.startEditing('m2');
        final second = notifier.saveEdit('m1', 'edited1b');

        firstRequest.complete();
        await first;
        await second;

        expect(notifier.editingMessageId, 'm2');
        expect(notifier.messages.first['content'], 'edited1b');
      },
    );

    test('reverts when two overlapping edits both fail', () async {
      when(
        () => mockRepository.editMessage(
          any(),
          content: any(named: 'content'),
          threadId: any(named: 'threadId'),
        ),
      ).thenThrow(Exception('network error'));

      notifier.startEditing('m1');
      final first = notifier.saveEdit('m1', 'edited1');
      notifier.startEditing('m1');
      final second = notifier.saveEdit('m1', 'edited2');

      await first;
      await second;

      expect(notifier.messages.single['content'], 'hello');
    });
  });
}

void _deleteTests() {
  group('ChatHistoryNotifier.deleteMessage', () {
    late MockDmRepository mockRepository;
    late ProviderContainer container;
    late ChatHistoryNotifier notifier;

    setUp(() async {
      mockRepository = MockDmRepository();
      when(
        () => mockRepository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => [
          {'id': 'm1', 'content': 'hello', 'user_id': 'u1'},
          {'id': 'm2', 'content': 'again', 'user_id': 'u1'},
        ],
      );
      container = ProviderContainer(
        overrides: [dmRepositoryProvider.overrideWithValue(mockRepository)],
      );
      notifier = container
          .listen(chatHistoryProvider('ch-1'), (_, _) {})
          .read();
      await pumpEventQueue();
    });

    tearDown(() => container.dispose());

    test('removes the message and calls the delete endpoint', () async {
      when(
        () => mockRepository.deleteMessage(
          threadId: any(named: 'threadId'),
          channelId: any(named: 'channelId'),
        ),
      ).thenAnswer((_) async {});

      await notifier.deleteMessage('m1');

      expect(notifier.messages.map((m) => m['id']), ['m2']);
      verify(
        () => mockRepository.deleteMessage(threadId: 'm1', channelId: 'ch-1'),
      ).called(1);
    });

    test('does not bring a deleted message back when polling', () async {
      when(
        () => mockRepository.deleteMessage(
          threadId: any(named: 'threadId'),
          channelId: any(named: 'channelId'),
        ),
      ).thenAnswer((_) async {});

      await notifier.deleteMessage('m1');
      await notifier.loadMore();

      expect(notifier.messages.map((m) => m['id']), isNot(contains('m1')));
    });

    test('puts the message back when the request fails', () async {
      when(
        () => mockRepository.deleteMessage(
          threadId: any(named: 'threadId'),
          channelId: any(named: 'channelId'),
        ),
      ).thenThrow(Exception('network error'));

      await notifier.deleteMessage('m1');

      expect(notifier.messages.map((m) => m['id']), ['m1', 'm2']);
    });
  });
}

void _loadErrorTests() {
  group('ChatHistoryNotifier load errors', () {
    late MockDmRepository mockRepository;
    late ProviderContainer container;

    List<Map<String, dynamic>> page(int count, String prefix) => [
      for (var i = 0; i < count; i++)
        {'id': '$prefix$i', 'content': 'msg $i', 'user_id': 'u1'},
    ];

    setUp(() {
      mockRepository = MockDmRepository();
      container = ProviderContainer(
        overrides: [dmRepositoryProvider.overrideWithValue(mockRepository)],
      );
    });

    tearDown(() => container.dispose());

    test('flags a failed first load and clears it on retry', () async {
      var fail = true;
      when(
        () => mockRepository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) async {
        if (fail) throw Exception('network error');
        return page(2, 'm');
      });

      final notifier = container
          .listen(chatHistoryProvider('ch-1'), (_, _) {})
          .read();
      await pumpEventQueue();

      expect(notifier.loadFailed, isTrue);
      expect(notifier.isLoading, isFalse);
      expect(notifier.messages, isEmpty);

      fail = false;
      await notifier.retryLoad();

      expect(notifier.loadFailed, isFalse);
      expect(notifier.messages.map((m) => m['id']), ['m0', 'm1']);
    });

    test('a successful first load reports no error', () async {
      when(
        () => mockRepository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => page(2, 'm'));

      final notifier = container
          .listen(chatHistoryProvider('ch-1'), (_, _) {})
          .read();
      await pumpEventQueue();

      expect(notifier.loadFailed, isFalse);
      expect(notifier.loadMoreFailed, isFalse);
    });

    test('a failed loadMore keeps hasMore and can be retried', () async {
      var failNextPage = true;
      when(
        () => mockRepository.getMessages(any(), page: 1),
      ).thenAnswer((_) async => page(DmRepository.pageSize, 'a'));
      when(() => mockRepository.getMessages(any(), page: 2)).thenAnswer((
        _,
      ) async {
        if (failNextPage) throw Exception('network error');
        return page(1, 'b');
      });

      final notifier = container
          .listen(chatHistoryProvider('ch-1'), (_, _) {})
          .read();
      await pumpEventQueue();
      await notifier.loadMore();

      expect(notifier.loadMoreFailed, isTrue);
      expect(notifier.hasMore, isTrue);
      expect(notifier.page, 1);

      failNextPage = false;
      await notifier.loadMore();

      expect(notifier.loadMoreFailed, isFalse);
      expect(notifier.page, 2);
      expect(notifier.messages.last['id'], 'b0');
    });
  });
}

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

void _retryTests() {
  group('ChatHistoryNotifier.retryMessage', () {
    late MockDmRepository mockRepository;
    late ProviderContainer container;
    late ChatHistoryNotifier notifier;

    setUp(() async {
      mockRepository = MockDmRepository();
      when(
        () => mockRepository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => []);

      container = ProviderContainer(
        overrides: [
          dmRepositoryProvider.overrideWithValue(mockRepository),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        ],
      );
      notifier = container
          .listen(chatHistoryProvider('channel-xyz'), (_, _) {})
          .read();
      await pumpEventQueue();
    });

    tearDown(() => container.dispose());

    test(
      'stores is_channel in optimistic message when sending channel message',
      () async {
        when(
          () => mockRepository.sendMessage(
            any(),
            any(),
            media: any(named: 'media'),
            mentions: any(named: 'mentions'),
            isChannel: any(named: 'isChannel'),
          ),
        ).thenAnswer((_) async => 'thread-1');

        await notifier.sendMessage('test content', isChannel: true);

        expect(notifier.messages.isNotEmpty, isTrue);
        expect(notifier.messages.first['is_channel'], isTrue);
      },
    );

    test(
      'retryMessage reads is_channel directly from failed message payload even when sendOptions are absent',
      () async {
        when(
          () => mockRepository.sendMessage(
            any(),
            any(),
            media: any(named: 'media'),
            mentions: any(named: 'mentions'),
            isChannel: any(named: 'isChannel'),
          ),
        ).thenAnswer((_) async => 'thread-retry');

        notifier.messages = [
          {
            'id': 'failed-msg-1',
            'content': 'Retrying channel message',
            'channel_id': 'channel-xyz',
            'status': 'failed',
            'is_channel': true,
          },
        ];

        await notifier.retryMessage('failed-msg-1');

        verify(
          () => mockRepository.sendMessage(
            'channel-xyz',
            'Retrying channel message',
            media: null,
            isChannel: true,
          ),
        ).called(1);
        expect(notifier.messages.first['status'], isNull);
        expect(notifier.messages.first['thread_id'], 'thread-retry');
      },
    );

    test(
      'retryMessage falls back to isChannel: false when message is a DM and has no is_channel flag',
      () async {
        when(
          () => mockRepository.sendMessage(
            any(),
            any(),
            media: any(named: 'media'),
            mentions: any(named: 'mentions'),
            isChannel: any(named: 'isChannel'),
          ),
        ).thenAnswer((_) async => 'thread-dm');

        notifier.messages = [
          {
            'id': 'failed-dm-1',
            'content': 'Retrying DM message',
            'channel_id': 'channel-xyz',
            'status': 'failed',
          },
        ];

        await notifier.retryMessage('failed-dm-1');

        verify(
          () => mockRepository.sendMessage(
            'channel-xyz',
            'Retrying DM message',
            media: null,
            isChannel: false,
          ),
        ).called(1);
      },
    );

    test('auto-disposes ChatHistoryNotifier when listener closes', () async {
      final sub = container.listen(chatHistoryProvider('ch-auto'), (_, _) {});
      final autoNotifier = sub.read();
      // ignore: invalid_use_of_protected_member
      expect(autoNotifier.hasListeners, isTrue);

      sub.close();
      await pumpEventQueue();

      expect(
        () => autoNotifier.notifyListeners(),
        throwsA(isA<FlutterError>()),
      );
    });
  });
}

void _clearHistoryTests() {
  group('ChatHistoryNotifier.clearLocalHistory', () {
    late MockDmRepository mockRepository;
    late _MemoryStorage storage;
    var serverMessages = <Map<String, dynamic>>[];

    final older = {
      'id': 'm1',
      'content': 'old',
      'user_id': 'u2',
      'created_at': '2026-11-01T09:00:00Z',
    };
    final newest = {
      'id': 'm2',
      'content': 'last before clear',
      'user_id': 'u2',
      'created_at': '2026-11-01T10:00:00Z',
    };
    final afterClear = {
      'id': 'm3',
      'content': 'after clear',
      'user_id': 'u2',
      'created_at': '2026-11-01T11:00:00Z',
    };

    setUp(() {
      mockRepository = MockDmRepository();
      storage = _MemoryStorage();
      serverMessages = [newest, older];
      when(
        () => mockRepository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => List.of(serverMessages));
    });

    // Each container is a fresh app session sharing the same device storage.
    Future<ChatHistoryNotifier> open() async {
      final container = ProviderContainer(
        overrides: [
          dmRepositoryProvider.overrideWithValue(mockRepository),
          dmHistoryClearStoreProvider.overrideWithValue(
            DmHistoryClearStore(storage, userId: 'u1'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container
          .listen(chatHistoryProvider('ch-1'), (_, _) {})
          .read();
      await pumpEventQueue();
      return notifier;
    }

    test('is not marked cleared before Clear history is used', () async {
      final notifier = await open();

      expect(notifier.historyCleared, isFalse);
      expect(notifier.messages.map((m) => m['id']), ['m2', 'm1']);
    });

    test('empties the chat and marks it cleared', () async {
      final notifier = await open();

      await notifier.clearLocalHistory();

      expect(notifier.messages, isEmpty);
      expect(notifier.hasMore, isFalse);
      expect(notifier.historyCleared, isTrue);
    });

    test('keeps cleared messages hidden after the DM is reopened', () async {
      final first = await open();
      await first.clearLocalHistory();

      final reopened = await open();

      expect(reopened.messages, isEmpty);
      expect(reopened.historyCleared, isTrue);
      expect(reopened.hasMore, isFalse);
    });

    test('still shows messages sent after the clear', () async {
      final first = await open();
      await first.clearLocalHistory();
      serverMessages = [afterClear, newest, older];

      final reopened = await open();

      expect(reopened.messages.map((m) => m['id']), ['m3']);
      expect(reopened.hasMore, isFalse);
    });

    test('stores the clear per user and conversation', () async {
      final first = await open();
      await first.clearLocalHistory();

      expect(storage.values.keys, ['dm_history_cleared_u1_ch-1']);
    });
  });
}
