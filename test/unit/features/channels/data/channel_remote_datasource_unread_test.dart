import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

ApiResponseModel<Map<String, dynamic>> _listResponse(
  List<Map<String, dynamic>> items,
) {
  return ApiResponseModel<Map<String, dynamic>>(
    data: {'data': items},
    statusCode: 200,
  );
}

Map<String, dynamic> _channelJson(String id, {int unreadCount = 0}) {
  return {
    'channels_id': id,
    'name': id,
    'description': '',
    'organisation_id': 'org-1',
    'owner_id': 'u1',
    'unread_count': unreadCount,
  };
}

void main() {
  group('ChannelRemoteDataSourceImpl.fetchChannels unread counts', () {
    late MockApiBaseService mockApi;
    late ChannelRemoteDataSourceImpl datasource;

    setUp(() {
      mockApi = MockApiBaseService();
      datasource = ChannelRemoteDataSourceImpl(
        apiBaseService: mockApi,
        config: AppConfig(
          apiBaseUrl: 'https://example.test',
          usesMockData: false,
        ),
      );
    });

    // fetchChannels pages the channel list (Ziki #1433); one short page is
    // the whole list.
    void stubChannels(List<Map<String, dynamic>> items) {
      when(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/channels',
          queryParameters: {
            'page': 1,
            'limit': ChannelRemoteDataSourceImpl.channelPageSize,
          },
        ),
      ).thenAnswer((_) async => _listResponse(items));
    }

    void stubUserChannels(List<Map<String, dynamic>> items) {
      when(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/user-channels',
        ),
      ).thenAnswer((_) async => _listResponse(items));
    }

    test('merges unread counts from user-channels into the list', () async {
      stubChannels([_channelJson('c1'), _channelJson('c2')]);
      stubUserChannels([
        _channelJson('c1', unreadCount: 3),
        _channelJson('c2', unreadCount: 0),
      ]);

      final channels = await datasource.fetchChannels('org-1');

      expect(channels.map((c) => c.id), ['c1', 'c2']);
      expect(channels.map((c) => c.unreadCount), [3, 0]);
    });

    test('leaves channels missing from user-channels at zero', () async {
      stubChannels([_channelJson('c1'), _channelJson('c2')]);
      stubUserChannels([_channelJson('c1', unreadCount: 2)]);

      final channels = await datasource.fetchChannels('org-1');

      expect(channels.map((c) => c.unreadCount), [2, 0]);
    });

    test('returns the base list when user-channels fails', () async {
      stubChannels([_channelJson('c1')]);
      when(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/user-channels',
        ),
      ).thenThrow(const ApiFailure(message: 'boom'));

      final channels = await datasource.fetchChannels('org-1');

      expect(channels.map((c) => c.id), ['c1']);
      expect(channels.single.unreadCount, 0);
    });

    test('fetchChannelUnreadCounts reads ids and counts', () async {
      stubUserChannels([
        _channelJson('c1', unreadCount: 4),
        {'id': 'c2', 'unread_count': 1},
      ]);

      expect(await datasource.fetchChannelUnreadCounts('org-1'), {
        'c1': 4,
        'c2': 1,
      });
    });
  });
}
