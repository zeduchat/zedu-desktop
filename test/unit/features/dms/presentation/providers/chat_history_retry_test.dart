import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class RetryRepository extends Mock implements DmRepository {}

class RetryAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

class RetryClearStore extends Fake implements DmHistoryClearStore {
  @override
  Future<DateTime?> clearedAt(String channelId) async => null;
}

void main() {
  late ProviderContainer container;
  late ChatHistoryNotifier history;
  late List<Completer<String>> requests;
  late List<({List<XFile>? media, bool isChannel})> payloads;

  setUp(() async {
    requests = [];
    payloads = [];
    final repository = RetryRepository();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => []);
    when(
      () => repository.sendMessage(
        any(),
        any(),
        media: any(named: 'media'),
        mentions: any(named: 'mentions'),
        isChannel: any(named: 'isChannel'),
      ),
    ).thenAnswer((call) {
      final request = Completer<String>();
      requests.add(request);
      payloads.add((
        media: call.namedArguments[#media] as List<XFile>?,
        isChannel: call.namedArguments[#isChannel] as bool,
      ));
      return request.future;
    });
    container = ProviderContainer(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repository),
        authNotifierProvider.overrideWith(RetryAuth.new),
        dmHistoryClearStoreProvider.overrideWithValue(RetryClearStore()),
      ],
    );
    history = container.listen(chatHistoryProvider('dm-1'), (_, _) {}).read();
    await pumpEventQueue();
  });

  tearDown(() => container.dispose());

  void seedFailed(List<String> ids) {
    history.messages = [
      for (final id in ids)
        {'id': id, 'content': 'Message $id', 'status': 'failed'},
    ];
  }

  Future<void> finish(List<Future<void>> operations) async {
    // A retry after a failed attempt first looks for a copy that reached the
    // server, so its request starts only after that lookup.
    await pumpEventQueue();
    for (final request in requests) {
      if (!request.isCompleted) request.complete('server-thread');
    }
    await Future.wait(operations);
  }

  test('overlapping retries of one failed message send only once', () async {
    seedFailed(['failed-1']);

    final first = history.retryMessage('failed-1');
    final repeat = history.retryMessage('failed-1');
    expect(history.messages.single['status'], 'sending');
    await finish([first, repeat]);

    expect(requests, hasLength(1));
    expect(history.messages.single['status'], isNull);
    expect(history.messages.single['thread_id'], 'server-thread');
  });

  test('a stale retry callback cannot resend a successful message', () async {
    seedFailed(['failed-1']);
    await finish([history.retryMessage('failed-1')]);

    await finish([history.retryMessage('failed-1')]);

    expect(requests, hasLength(1));
    expect(history.messages.single['status'], isNull);
  });

  test(
    'retry cannot duplicate a message whose initial send is pending',
    () async {
      final sending = history.sendMessage('New message');
      final id = history.messages.single['id'] as String;

      await finish([sending, history.retryMessage(id)]);

      expect(requests, hasLength(1));
      expect(history.messages.single['status'], isNull);
    },
  );

  test('a failed retry allows a later deliberate retry', () async {
    seedFailed(['failed-1']);
    final first = history.retryMessage('failed-1');
    requests.single.completeError(Exception('Offline'));
    await first;
    expect(history.messages.single['status'], 'failed');

    final next = history.retryMessage('failed-1');
    // The delivered-copy lookup runs before the message goes back to sending.
    await pumpEventQueue();
    expect(history.messages.single['status'], 'sending');
    await finish([next]);

    expect(requests, hasLength(2));
    expect(history.messages.single['status'], isNull);
  });

  test('different failed messages retry independently', () async {
    seedFailed(['failed-1', 'failed-2']);
    final first = history.retryMessage('failed-1');
    final second = history.retryMessage('failed-2');
    expect(requests, hasLength(2));
    expect(history.messages.every((m) => m['status'] == 'sending'), isTrue);

    requests.first.completeError(Exception('Offline'));
    requests.last.complete('second-thread');
    await Future.wait([first, second]);

    expect(history.messages.first['status'], 'failed');
    expect(history.messages.last['status'], isNull);
    expect(history.messages.last['thread_id'], 'second-thread');
  });

  test('retry preserves the original attachment and channel route', () async {
    final file = XFile.fromData(Uint8List.fromList([1, 2]), name: 'sample.txt');
    final sending = history.sendMessage(
      'Attachment',
      media: [file],
      isChannel: true,
    );
    requests.single.completeError(Exception('Offline'));
    await sending;
    final id = history.messages.single['id'] as String;

    await finish([history.retryMessage(id)]);

    expect(requests, hasLength(2));
    expect(payloads.every((p) => p.isChannel), isTrue);
    expect(payloads.map((p) => p.media!.single), [file, file]);
    expect(history.messages.single['status'], isNull);
  });
}
