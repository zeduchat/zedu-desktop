import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockApi extends Mock implements ApiBaseService {}

void main() {
  late _MockApi api;
  late DmRepository repository;

  setUp(() {
    api = _MockApi();
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
            {'id': 't1', 'content': 'hello'},
          ],
        },
      ),
    );
    when(
      () => api.post<Map<String, dynamic>>(
        path: any(named: 'path'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => const ApiResponseModel<Map<String, dynamic>>(
        statusCode: 201,
        data: {
          'data': {'thread_id': 'server-thread'},
        },
      ),
    );
  });

  group('DmRepository group DM routes (Ziki #2953)', () {
    test(
      'a group loads history from /group-dms/channels/{id}/threads',
      () async {
        final messages = await repository.getMessages('g1', isGroup: true);

        verify(
          () => api.get<Map<String, dynamic>>(
            path: '/group-dms/channels/g1/threads',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).called(1);
        expect(messages.single['id'], 't1');
      },
    );

    test('a one-to-one DM keeps its route', () async {
      await repository.getMessages('d1');

      verify(
        () => api.get<Map<String, dynamic>>(
          path: '/channels/d1/messages',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).called(1);
    });

    test(
      'a group message is sent to /group-dms/channels/{id}/threads',
      () async {
        await repository.sendMessage('g1', '<p>hi</p>', isGroup: true);

        verify(
          () => api.post<Map<String, dynamic>>(
            path: '/group-dms/channels/g1/threads',
            data: any(named: 'data'),
          ),
        ).called(1);
      },
    );

    test('a DM message keeps the DM route', () async {
      await repository.sendMessage('d1', '<p>hi</p>');

      verify(
        () => api.post<Map<String, dynamic>>(
          path: '/dms/channels/d1/threads',
          data: any(named: 'data'),
        ),
      ).called(1);
    });
  });
}
