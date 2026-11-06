import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late SavedRepository repository;

  setUp(() {
    api = MockApiBaseService();
    repository = SavedRepository(api);
  });

  ApiResponseModel<Map<String, dynamic>> ok([
    Map<String, dynamic> body = const {},
  ]) => ApiResponseModel<Map<String, dynamic>>(statusCode: 200, data: body);

  group('list', () {
    test('reads the rows the server returns, with the reminder time', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/organisations/org-1/saved/message',
        ),
      ).thenAnswer(
        (_) async => ok({
          'data': [
            {
              'id': 'saved-1',
              'thread_id': 'thread-1',
              'channel_id': 'chan-1',
              'channel_name': 'general',
              'channel_type': 'public',
              'username': 'Ada',
              'content': 'Deadline is Friday',
              'type': 'thread',
              'saved_at': '2026-11-06T08:00:00Z',
              'overdue_time': '2026-11-06T09:30:00Z',
            },
          ],
        }),
      );

      final items = await repository.list(orgId: 'org-1');

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.id, 'saved-1');
      expect(item.target.channelId, 'chan-1');
      expect(item.target.threadId, 'thread-1');
      expect(item.target.messageId, isNull);
      expect(item.kind, SavedMessageKind.thread);
      expect(item.authorName, 'Ada');
      expect(item.conversationLabel, '#general');
    });

    test('reads every row the server returns', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/organisations/org-1/saved/message',
        ),
      ).thenAnswer(
        (_) async => ok({
          'data': [
            {
              'id': 'saved-1',
              'thread_id': 't1',
              'channel_id': 'c1',
              'username': 'Ada',
              'content': 'one',
              'overdue': true,
              'overdue_time': '2026-11-01T09:00:00Z',
            },
            {
              'id': 'saved-2',
              'thread_id': 't2',
              'channel_id': 'c2',
              'username': 'Grace',
              'content': 'two',
            },
          ],
        }),
      );

      final items = await repository.list(orgId: 'org-1');

      expect(items.map((e) => e.id), ['saved-1', 'saved-2']);
      expect(items.first.authorName, 'Ada');
      expect(items.last.authorName, 'Grace');
    });

    test('names a direct message without a hash, and drops rows with no id', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/organisations/org-1/saved/message',
        ),
      ).thenAnswer(
        (_) async => ok({
          'data': [
            {
              'id': 'saved-1',
              'thread_id': 't1',
              'channel_id': 'c1',
              'channel_name': 'Ada Lovelace',
              'channel_type': 'dm',
              'username': 'Ada',
              'content': '  line one\n\n  line two  ',
            },
            {'thread_id': 'no-id', 'channel_id': 'c9'},
          ],
        }),
      );

      final items = await repository.list(orgId: 'org-1');

      expect(items, hasLength(1));
      expect(items.single.conversationLabel, 'Ada Lovelace');
      expect(items.single.isDirectMessage, isTrue);
      // A multi-line message must not stretch a row.
      expect(items.single.preview, 'line one line two');
    });

    test('an empty or malformed payload is an empty list, not a crash', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/organisations/org-1/saved/message',
        ),
      ).thenAnswer((_) async => ok({'data': 'not a list'}));

      expect(await repository.list(orgId: 'org-1'), isEmpty);
    });
  });

  group('save', () {
    test('a top-level message goes to the thread endpoint', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => ok());

      await repository.save(
        orgId: 'org-1',
        target: const SavedTarget(channelId: 'chan-1', threadId: 'thread-1'),
      );

      final call = verify(
        () => api.post<Map<String, dynamic>>(
          path: captureAny(named: 'path'),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(call[0], '/organisations/org-1/thread/save');
      expect(call[1], {'channels_id': 'chan-1', 'thread_id': 'thread-1'});
    });

    test('a reply goes to the message endpoint and sends its own id', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => ok());

      await repository.save(
        orgId: 'org-1',
        target: const SavedTarget(
          channelId: 'chan-1',
          threadId: 'thread-1',
          messageId: 'reply-7',
        ),
      );

      final call = verify(
        () => api.post<Map<String, dynamic>>(
          path: captureAny(named: 'path'),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(call[0], '/organisations/org-1/message/save');
      expect(call[1], {
        'channels_id': 'chan-1',
        'thread_id': 'thread-1',
        'message_id': 'reply-7',
      });
    });
  });

  test('removing uses the saved item id, not the thread id', () async {
    when(
      () => api.delete<Map<String, dynamic>>(path: any(named: 'path')),
    ).thenAnswer((_) async => ok());

    await repository.remove(orgId: 'org-1', savedMessageId: 'saved-42');

    verify(
      () => api.delete<Map<String, dynamic>>(
        path: '/organisations/org-1/saved/message/saved-42',
      ),
    ).called(1);
  });
}
