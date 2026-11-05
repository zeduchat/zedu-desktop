import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late ChannelNotificationService service;

  setUp(() {
    api = MockApiBaseService();
    service = ChannelNotificationService(api);
  });

  test('loads the channel preference the way the web reads it', () async {
    when(
      () => api.get<Map<String, dynamic>>(
        path: '/channels/ch-1/notification-preference',
        queryParameters: {'device_type': 'desktop'},
      ),
    ).thenAnswer(
      (_) async => const ApiResponseModel(
        statusCode: 200,
        data: {
          'data': {'at_channel': false, 'at_mentions': true, 'muted': true},
        },
      ),
    );

    final preference = await service.load('ch-1');

    expect(preference.level, ChannelNotificationLevel.mentions);
    expect(preference.muted, isTrue);
  });

  test('reads both flags on as all new messages', () {
    final preference = ChannelNotificationPreference.fromJson(const {
      'at_channel': true,
      'at_mentions': true,
    });
    expect(preference.level, ChannelNotificationLevel.all);
    expect(preference.muted, isFalse);
  });

  test('saves the choice to the channel endpoint', () async {
    when(
      () => api.post<Map<String, dynamic>>(
        path: any(named: 'path'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => const ApiResponseModel(statusCode: 200, data: {}),
    );

    await service.save(
      'ch-1',
      const ChannelNotificationPreference(
        level: ChannelNotificationLevel.channels,
        muted: false,
      ),
    );

    verify(
      () => api.post<Map<String, dynamic>>(
        path: '/channels/ch-1/notification-preference',
        data: {
          'muted': false,
          'at_mentions': false,
          'at_channel': true,
          'device_type': 'desktop',
        },
      ),
    ).called(1);
  });
}
