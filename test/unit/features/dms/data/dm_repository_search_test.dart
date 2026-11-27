import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('DmRepository.searchMessages', () {
    late MockApiBaseService api;
    late DmRepository repository;

    setUp(() {
      api = MockApiBaseService();
      repository = DmRepository(api);
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
              {
                'user': {'user_name': 'Ada Obi'},
                'messages': [
                  {'message_id': 'm1', 'message': 'budget'},
                ],
              },
            ],
          },
        ),
      );
    });

    test('calls the conversation search endpoint like Zedu web', () async {
      final hits = await repository.searchMessages(
        channelId: 'chat-1',
        query: '  budget ',
      );

      verify(
        () => api.get<Map<String, dynamic>>(
          path: '/search/channel/chat-1',
          queryParameters: {'query': 'budget', 'sortby': 'relevance'},
        ),
      ).called(1);
      expect(hits.single.messageId, 'm1');
    });

    test('does not call the server for a blank query', () async {
      expect(
        await repository.searchMessages(channelId: 'chat-1', query: '  '),
        isEmpty,
      );
      verifyNever(
        () => api.get<Map<String, dynamic>>(
          path: any(named: 'path'),
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    });
  });
}
