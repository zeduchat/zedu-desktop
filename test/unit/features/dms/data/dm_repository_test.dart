import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late DmRepository repository;

  setUp(() {
    api = MockApiBaseService();
    repository = DmRepository(api);
  });

  group('DmRepository.sendMessage', () {
    Map<String, dynamic> sentBody() {
      final captured = verify(
        () => api.post<Map<String, dynamic>>(
          path: '/dms/channels/ch-1/threads',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      return captured.single as Map<String, dynamic>;
    }

    void stubUploadAndSend() {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/files/upload-files',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': [
              {'url': 'https://files.test/voice.m4a'},
            ],
          },
        ),
      );
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/dms/channels/ch-1/threads',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {},
        ),
      );
    }

    test('sends an empty paragraph for a voice note with no text', () async {
      stubUploadAndSend();

      await repository.sendMessage(
        'ch-1',
        '',
        media: [XFile.fromData(Uint8List(3), name: 'voice.m4a')],
      );

      expect(sentBody()['content'], '<p></p>');
    });

    test('keeps the typed text when media is attached', () async {
      stubUploadAndSend();

      await repository.sendMessage(
        'ch-1',
        'listen to this',
        media: [XFile.fromData(Uint8List(3), name: 'voice.m4a')],
      );

      expect(sentBody()['content'], 'listen to this');
    });

    test('leaves empty text alone when there is no media', () async {
      stubUploadAndSend();

      await repository.sendMessage('ch-1', '');

      expect(sentBody()['content'], '');
    });
  });

  group('DmRepository thread id', () {
    void stubSend(Map<String, dynamic> data) {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/dms/channels/ch-1/threads',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async =>
            ApiResponseModel<Map<String, dynamic>>(statusCode: 201, data: data),
      );
    }

    test(
      'returns the thread id the server created, not the one sent',
      () async {
        stubSend({
          'data': {'thread_id': 'server-thread'},
        });

        final threadId = await repository.sendMessage('ch-1', 'hello');

        expect(threadId, 'server-thread');
      },
    );

    test('falls back to the id it sent when the reply has none', () async {
      stubSend({});

      final threadId = await repository.sendMessage('ch-1', 'hello');

      final captured =
          verify(
                () => api.post<Map<String, dynamic>>(
                  path: '/dms/channels/ch-1/threads',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(threadId, captured['thread_id']);
    });
  });

  group('DmRepository.deleteMessage', () {
    test('deletes through the DM route', () async {
      when(
        () => api.delete<Map<String, dynamic>>(
          path: '/dms/thread/thread-1/channels/ch-1',
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {},
        ),
      );

      await repository.deleteMessage(threadId: 'thread-1', channelId: 'ch-1');

      verify(
        () => api.delete<Map<String, dynamic>>(
          path: '/dms/thread/thread-1/channels/ch-1',
        ),
      ).called(1);
    });
  });

  group('DmRepository.pinMessage', () {
    test('pins the thread through the channels pin route', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/channels/pin/ch-1/thread',
          data: {'thread_id': 'thread-1'},
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 201,
          data: {},
        ),
      );

      await repository.pinMessage(threadId: 'thread-1', channelId: 'ch-1');

      verify(
        () => api.post<Map<String, dynamic>>(
          path: '/channels/pin/ch-1/thread',
          data: {'thread_id': 'thread-1'},
        ),
      ).called(1);
    });
  });

  group('DmRepository.openConversation', () {
    test('returns the channel and participant ids', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/organisations/org-1/dms',
          data: {'chat_type': 'user', 'participant_id': 'u-2'},
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {'channel_id': 'ch-9', 'participant_id': 'u-2'},
          },
        ),
      );

      final opened = await repository.openConversation(
        orgId: 'org-1',
        participantId: 'u-2',
      );

      expect(opened.channelId, 'ch-9');
      expect(opened.participantId, 'u-2');
    });

    test('rejects a response with an empty channel id', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/organisations/org-1/dms',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {'channel_id': '', 'participant_id': 'u-2'},
          },
        ),
      );

      expect(
        repository.openConversation(orgId: 'org-1', participantId: 'u-2'),
        throwsFormatException,
      );
    });
  });

  group('DmRepository.editMessage', () {
    test('sends messageId in the URL path and content in data', () async {
      when(
        () => api.put<Map<String, dynamic>>(
          path: '/dms/messages/msg-123',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {},
        ),
      );

      await repository.editMessage('msg-123', content: 'Updated message text');

      verify(
        () => api.put<Map<String, dynamic>>(
          path: '/dms/messages/msg-123',
          data: {'content': 'Updated message text'},
        ),
      ).called(1);
    });
  });

  group('DmRepository.getConversations', () {
    test(
      'parses pagination data when present and determines hasMore',
      () async {
        when(
          () => api.get<Map<String, dynamic>>(
            path: '/organisations/org-1/dms',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async => const ApiResponseModel<Map<String, dynamic>>(
            statusCode: 200,
            data: {
              'data': [
                {
                  'channel_id': 'ch-1',
                  'username': 'Alice',
                  'participant_id': 'u-1',
                  'preview_message': 'Hey',
                  'unread_count': 0,
                },
              ],
              'pagination': {
                'current_page': 1,
                'total_pages': 3,
                'page_size': 20,
                'total_items': 45,
              },
            },
          ),
        );

        final page = await repository.getConversations(orgId: 'org-1', page: 1);

        expect(page.conversations.length, 1);
        expect(page.currentPage, 1);
        expect(page.totalPages, 3);
        expect(page.totalItems, 45);
        expect(page.hasMore, isTrue);
      },
    );

    test(
      'determines hasMore is false when on last page with short results',
      () async {
        when(
          () => api.get<Map<String, dynamic>>(
            path: '/organisations/org-1/dms',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async => const ApiResponseModel<Map<String, dynamic>>(
            statusCode: 200,
            data: {
              'data': [
                {
                  'channel_id': 'ch-2',
                  'username': 'Bob',
                  'participant_id': 'u-2',
                  'preview_message': 'Hello',
                  'unread_count': 0,
                },
              ],
              'pagination': {
                'current_page': 3,
                'total_pages': 3,
                'page_size': 20,
                'total_items': 41,
              },
            },
          ),
        );

        final page = await repository.getConversations(orgId: 'org-1', page: 3);

        expect(page.hasMore, isFalse);
      },
    );
  });

  group('DmRepository.getMessages', () {
    void stubThreads(Map<String, dynamic> body) {
      when(
        () => api.get<Map<String, dynamic>>(
          path: any(named: 'path'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async =>
            ApiResponseModel<Map<String, dynamic>>(data: body, statusCode: 200),
      );
    }

    test('loads history from the DM threads route', () async {
      stubThreads({'data': <dynamic>[]});

      await repository.getMessages('ch-1', page: 2);

      verify(
        () => api.get<Map<String, dynamic>>(
          path: '/dms/channels/ch-1/threads',
          queryParameters: {'page': 2, 'limit': DmRepository.pageSize},
        ),
      ).called(1);
    });

    test('maps each thread to the message shape the chat reads', () async {
      stubThreads({
        'data': [
          {
            'thread_id': 'thread-1',
            'message': '<p>hello</p>',
            'user_id': 'user-2',
            'username': 'ada',
            'created_at': '2026-10-16T19:19:04Z',
            'status': 'active',
          },
        ],
      });

      final messages = await repository.getMessages('ch-1');

      expect(messages, hasLength(1));
      final message = messages.single;
      expect(message['id'], 'thread-1');
      expect(message['content'], '<p>hello</p>');
      expect(message['user_id'], 'user-2');
      expect(message['username'], 'ada');
      expect(message['created_at'], '2026-10-16T19:19:04Z');
      // A status on a loaded message means "sending" or "failed" to the chat.
      expect(message.containsKey('status'), isFalse);
    });

    test('returns an empty list when data is not a list', () async {
      stubThreads({'data': null});

      expect(await repository.getMessages('ch-1'), isEmpty);
    });

    test('uses an empty string when the thread has no text', () {
      final message = DmRepository.threadToMessage({'thread_id': 'thread-1'});

      expect(message['id'], 'thread-1');
      expect(message['content'], '');
    });
  });
}
