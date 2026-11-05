import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('ChannelRemoteDataSourceImpl.toggleStarChannel', () {
    late MockApiBaseService mockApi;
    late ChannelRemoteDataSourceImpl datasource;

    setUp(() {
      mockApi = MockApiBaseService();
      datasource = ChannelRemoteDataSourceImpl(apiBaseService: mockApi);
    });

    void stubResponse(Map<String, dynamic> body) {
      when(
        () => mockApi.post<Map<String, dynamic>>(
          path: '/organisations/org-1/channels/ch-1/star',
        ),
      ).thenAnswer(
        (_) async =>
            ApiResponseModel<Map<String, dynamic>>(data: body, statusCode: 200),
      );
    }

    test('posts to the channel star path and returns the new state', () async {
      stubResponse({
        'data': {'is_starred': true, 'channel_id': 'ch-1'},
      });

      final starred = await datasource.toggleStarChannel(
        orgId: 'org-1',
        channelId: 'ch-1',
      );

      expect(starred, isTrue);
      verify(
        () => mockApi.post<Map<String, dynamic>>(
          path: '/organisations/org-1/channels/ch-1/star',
        ),
      ).called(1);
    });

    test('returns false when the channel was unstarred', () async {
      stubResponse({
        'data': {'is_starred': false, 'channel_id': 'ch-1'},
      });

      expect(
        await datasource.toggleStarChannel(orgId: 'org-1', channelId: 'ch-1'),
        isFalse,
      );
    });

    test('fails when the response has no star state', () async {
      stubResponse({'data': null});

      await expectLater(
        datasource.toggleStarChannel(orgId: 'org-1', channelId: 'ch-1'),
        throwsException,
      );
    });

    test('passes a request failure on to the caller', () async {
      const failure = ApiFailure(
        message: 'channel not found',
        kind: ApiFailureKind.notFound,
      );
      when(
        () => mockApi.post<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenThrow(failure);

      await expectLater(
        datasource.toggleStarChannel(orgId: 'org-1', channelId: 'ch-1'),
        throwsA(failure),
      );
    });
  });
}
