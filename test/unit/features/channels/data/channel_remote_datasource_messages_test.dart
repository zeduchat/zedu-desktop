import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService mockApi;
  late ChannelRemoteDataSourceImpl datasource;

  setUp(() {
    mockApi = MockApiBaseService();
    datasource = ChannelRemoteDataSourceImpl(apiBaseService: mockApi);
  });

  void answer(Object? data) {
    when(
      () => mockApi.get<Map<String, dynamic>>(
        path: '/threads/channels/ch-1',
        queryParameters: {'page': 1, 'limit': 50},
      ),
    ).thenAnswer(
      (_) async => ApiResponseModel<Map<String, dynamic>>(
        data: {'data': data},
        statusCode: 200,
      ),
    );
  }

  test('fetchChannelMessages reads /threads/channels/{id}', () async {
    answer([
      {'thread_id': 't-1', 'username': 'ada', 'message': 'hello'},
    ]);

    final messages = await datasource.fetchChannelMessages('ch-1');

    expect(messages.single.text, 'hello');
  });

  test('fetchChannelMessages returns [] for a channel with none', () async {
    answer(null);

    expect(await datasource.fetchChannelMessages('ch-1'), isEmpty);
  });

  test('fetchChannelMessages throws on a malformed response', () async {
    answer({'not': 'a list'});

    expect(datasource.fetchChannelMessages('ch-1'), throwsA(isA<TypeError>()));
  });
}
