import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

const _webhookJson = {
  'id': 'wh-1',
  'channel_id': 'ch-1',
  'webhook_name': 'Deploys',
  'webhook_slug': 'deploys',
  'webhook_url': 'https://api.example.com/hooks/deploys',
  'status': 'active',
};

ApiResponseModel<Map<String, dynamic>> _ok(Object? data) =>
    ApiResponseModel(statusCode: 200, data: {'data': data});

void main() {
  late MockApiBaseService api;
  late ChannelWebhookService service;

  setUp(() {
    api = MockApiBaseService();
    service = ChannelWebhookService(api);
  });

  test(
    'fetches the channel webhook and reads the backend field names',
    () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/webhooks/ch-1'),
      ).thenAnswer((_) async => _ok(_webhookJson));

      final webhook = await service.fetch('ch-1');

      expect(webhook?.id, 'wh-1');
      expect(webhook?.name, 'Deploys');
      expect(webhook?.url, 'https://api.example.com/hooks/deploys');
      expect(webhook?.isActive, isTrue);
    },
  );

  test('a channel with no webhook (404) gives null, not an error', () async {
    when(() => api.get<Map<String, dynamic>>(path: '/webhooks/ch-1')).thenThrow(
      const ApiFailure(message: 'not found', kind: ApiFailureKind.notFound),
    );

    expect(await service.fetch('ch-1'), isNull);
  });

  test('other load failures are not hidden', () async {
    when(
      () => api.get<Map<String, dynamic>>(path: '/webhooks/ch-1'),
    ).thenThrow(const ApiFailure(message: 'down', kind: ApiFailureKind.server));

    expect(() => service.fetch('ch-1'), throwsA(isA<ApiFailure>()));
  });

  test('creates a webhook with the name the user typed', () async {
    when(
      () => api.post<Map<String, dynamic>>(
        path: '/webhooks/ch-1',
        data: {'webhook_name': 'Deploys'},
      ),
    ).thenAnswer((_) async => _ok(_webhookJson));

    final webhook = await service.create('ch-1', name: 'Deploys');

    expect(webhook.id, 'wh-1');
  });

  test('turns a webhook off with the change-status endpoint', () async {
    when(
      () => api.put<Map<String, dynamic>>(
        path: '/webhooks/ch-1/wh-1/change-status',
        data: {'webhook_status': 'inactive'},
      ),
    ).thenAnswer((_) async => _ok({..._webhookJson, 'status': 'inactive'}));

    final webhook = await service.setActive('ch-1', 'wh-1', active: false);

    expect(webhook?.isActive, isFalse);
  });

  test('deletes a webhook', () async {
    when(
      () => api.delete<Map<String, dynamic>>(path: '/webhooks/ch-1/wh-1'),
    ).thenAnswer((_) async => _ok(null));

    await service.delete('ch-1', 'wh-1');

    verify(
      () => api.delete<Map<String, dynamic>>(path: '/webhooks/ch-1/wh-1'),
    ).called(1);
  });
}
