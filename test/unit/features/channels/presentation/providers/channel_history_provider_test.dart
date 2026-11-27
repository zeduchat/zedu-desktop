import 'dart:async';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockChannelRepository extends Mock implements ChannelRepository {}

ChannelMessage _message(String id) =>
    ChannelMessage(id: id, senderName: 'Ada', text: 'message $id');

Success<ChannelMessagePage> _page(List<String> ids, {required bool hasMore}) =>
    Success(
      ChannelMessagePage(
        messages: ids.map(_message).toList(),
        hasMore: hasMore,
      ),
    );

void main() {
  late MockChannelRepository repository;
  late ProviderContainer container;

  void stubPage(int page, Result<ChannelMessagePage> result) {
    when(
      () => repository.fetchChannelMessages('ch-1', page: page),
    ).thenAnswer((_) async => result);
  }

  ChannelHistoryNotifier notifier() =>
      container.read(channelHistoryProvider('ch-1').notifier);

  ChannelHistoryState current() =>
      container.read(channelHistoryProvider('ch-1')).requireValue;

  Future<void> open() async {
    // autoDispose: keep it alive for the length of the test.
    container.listen(channelHistoryProvider('ch-1'), (_, _) {});
    await container.read(channelHistoryProvider('ch-1').future);
  }

  setUp(() {
    repository = MockChannelRepository();
    container = ProviderContainer(
      overrides: [channelRepositoryProvider.overrideWithValue(repository)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  });

  test('opens on the newest page', () async {
    stubPage(1, _page(['t-4', 't-3'], hasMore: true));

    await open();

    expect(current().messages.map((m) => m.id), ['t-4', 't-3']);
    expect(current().hasMore, isTrue);
    verifyNever(() => repository.fetchChannelMessages('ch-1', page: 2));
  });

  test('applyEdit replaces the text of the edited message only', () async {
    when(() => repository.fetchChannelMessages('ch-1', page: 1)).thenAnswer(
      (_) async => const Success(
        ChannelMessagePage(
          messages: [
            ChannelMessage(
              id: 't-2',
              senderName: 'Ada',
              text: 'other',
              threadId: 't-2',
            ),
            ChannelMessage(
              id: 't-1',
              senderName: 'Me',
              text: 'my typo',
              threadId: 't-1',
              userId: 'me',
            ),
          ],
          hasMore: true,
        ),
      ),
    );
    await open();

    notifier().applyEdit('t-1', 'fixed text');

    final messages = current().messages;
    expect(messages.map((m) => m.text), ['other', 'fixed text']);
    expect(messages.last.rawContent, 'fixed text');
    expect(messages.last.id, 't-1');
    expect(messages.last.userId, 'me');
    expect(current().hasMore, isTrue);
    verify(() => repository.fetchChannelMessages('ch-1', page: 1)).called(1);
  });

  test('applyEdit ignores a message that is not loaded', () async {
    stubPage(1, _page(['t-1'], hasMore: false));
    await open();
    final before = current();

    notifier().applyEdit('t-9', 'fixed text');

    expect(identical(current(), before), isTrue);
  });

  test('loadMore appends older messages in order', () async {
    stubPage(1, _page(['t-4', 't-3'], hasMore: true));
    stubPage(2, _page(['t-2', 't-1'], hasMore: false));
    await open();

    await notifier().loadMore();

    expect(current().messages.map((m) => m.id), ['t-4', 't-3', 't-2', 't-1']);
  });

  test('loadMore appends without duplicates', () async {
    stubPage(1, _page(['t-4', 't-3'], hasMore: true));
    // A message sent meanwhile shifted the pages: t-3 comes round again.
    stubPage(2, _page(['t-3', 't-2'], hasMore: false));
    await open();

    await notifier().loadMore();

    expect(current().messages.map((m) => m.id), ['t-4', 't-3', 't-2']);
  });

  test('hasMore stays true until the last page is loaded', () async {
    stubPage(1, _page(['t-6', 't-5'], hasMore: true));
    stubPage(2, _page(['t-4', 't-3'], hasMore: true));
    stubPage(3, _page(['t-2', 't-1'], hasMore: false));
    await open();

    await notifier().loadMore();
    expect(current().hasMore, isTrue);

    await notifier().loadMore();
    expect(current().hasMore, isFalse);
    expect(current().messages, hasLength(6));
  });

  test('loadMore does nothing after the last page', () async {
    stubPage(1, _page(['t-1'], hasMore: false));
    await open();

    await notifier().loadMore();

    verifyNever(() => repository.fetchChannelMessages('ch-1', page: 2));
  });

  test('loadMore ignores a call while a page is loading', () async {
    final pending = Completer<Result<ChannelMessagePage>>();
    stubPage(1, _page(['t-2'], hasMore: true));
    when(
      () => repository.fetchChannelMessages('ch-1', page: 2),
    ).thenAnswer((_) => pending.future);
    await open();

    final first = notifier().loadMore();
    await notifier().loadMore();
    expect(current().isLoadingMore, isTrue);

    pending.complete(_page(['t-1'], hasMore: false));
    await first;

    verify(() => repository.fetchChannelMessages('ch-1', page: 2)).called(1);
    expect(current().messages.map((m) => m.id), ['t-2', 't-1']);
    expect(current().isLoadingMore, isFalse);
  });

  test('a failed older page keeps the messages and can be retried', () async {
    stubPage(1, _page(['t-2'], hasMore: true));
    stubPage(2, const Failure(ApiFailure(message: 'boom')));
    await open();

    await notifier().loadMore();

    expect(current().loadMoreError, isNotNull);
    expect(current().isLoadingMore, isFalse);
    expect(current().hasMore, isTrue);
    expect(current().messages.map((m) => m.id), ['t-2']);

    stubPage(2, _page(['t-1'], hasMore: false));
    await notifier().loadMore();

    expect(current().loadMoreError, isNull);
    expect(current().messages.map((m) => m.id), ['t-2', 't-1']);
  });

  test('a page with nothing new ends the list', () async {
    stubPage(1, _page(['t-2', 't-1'], hasMore: true));
    // A backend that ignores `page` would send the same page again.
    stubPage(2, _page(['t-2', 't-1'], hasMore: true));
    await open();

    await notifier().loadMore();

    expect(current().hasMore, isFalse);
    expect(current().messages, hasLength(2));
  });

  test('a failed first page is an error state', () async {
    stubPage(1, const Failure(ApiFailure(message: 'boom')));
    container.listen(channelHistoryProvider('ch-1'), (_, _) {});

    await expectLater(
      container.read(channelHistoryProvider('ch-1').future),
      throwsA(isA<ApiFailure>()),
    );
  });
}
