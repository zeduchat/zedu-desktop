import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Reads and changes a channel's incoming webhook through `/webhooks/{channelId}`,
/// the same endpoints the web's channel settings use. A channel has at most
/// one webhook.
class ChannelWebhookService {
  ChannelWebhookService(this._api);

  final ApiBaseService _api;

  /// The channel's webhook, or null when it has none.
  Future<WebhookModel?> fetch(String channelId) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        path: '/webhooks/$channelId',
      );
      return _webhookFrom(response.data);
    } on ApiFailure catch (error) {
      if (error.kind == ApiFailureKind.notFound) return null;
      rethrow;
    }
  }

  Future<WebhookModel> create(String channelId, {required String name}) async {
    final response = await _api.post<Map<String, dynamic>>(
      path: '/webhooks/$channelId',
      data: {'webhook_name': name},
    );
    final webhook = _webhookFrom(response.data);
    if (webhook == null) {
      throw const ApiFailure(
        message: 'The webhook was not created. Please try again.',
        kind: ApiFailureKind.server,
      );
    }
    return webhook;
  }

  Future<WebhookModel?> setActive(
    String channelId,
    String webhookId, {
    required bool active,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      path: '/webhooks/$channelId/$webhookId/change-status',
      data: {'webhook_status': active ? 'active' : 'inactive'},
    );
    return _webhookFrom(response.data);
  }

  Future<void> delete(String channelId, String webhookId) async {
    await _api.delete<Map<String, dynamic>>(
      path: '/webhooks/$channelId/$webhookId',
    );
  }

  WebhookModel? _webhookFrom(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is! Map<String, dynamic> || data.isEmpty) return null;
    final webhook = WebhookModel.fromJson(data);
    return webhook.id.isEmpty ? null : webhook;
  }
}

final channelWebhookServiceProvider = Provider<ChannelWebhookService>(
  (ref) => ChannelWebhookService(locator<ApiBaseService>()),
);
