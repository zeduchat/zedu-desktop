import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late DmRepository repository;

  setUp(() {
    api = MockApiBaseService();
    repository = DmRepository(api);
  });

  test('loads replies from the DM thread endpoint like Zedu web', () async {
    when(
      () => api.get<Map<String, dynamic>>(
        path: any(named: 'path'),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => const ApiResponseModel<Map<String, dynamic>>(
        statusCode: 200,
        data: {
          'data': [
            {'id': 'r1', 'content': 'hi'},
            'not a reply',
          ],
        },
      ),
    );

    final replies = await repository.getThreadReplies(
      channelId: 'chat-1',
      threadId: 'thread-1',
    );

    verify(
      () => api.get<Map<String, dynamic>>(
        path: '/dms/thread/thread-1/channels/chat-1',
        queryParameters: {'page': 1, 'limit': 30},
      ),
    ).called(1);
    expect(replies.single['id'], 'r1');
  });

  test('posts a reply with the thread id like Zedu web', () async {
    when(
      () => api.post<Map<String, dynamic>>(
        path: any(named: 'path'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => const ApiResponseModel<Map<String, dynamic>>(
        statusCode: 201,
        data: {},
      ),
    );

    await repository.replyToThread(
      channelId: 'chat-1',
      threadId: 'thread-1',
      content: 'On it',
    );

    verify(
      () => api.post<Map<String, dynamic>>(
        path: '/dms/messages/chat-1',
        data: {'content': 'On it', 'thread_id': 'thread-1'},
      ),
    ).called(1);
  });
}
