import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('WebhookModel', () {
    test('parses a camelCase payload', () {
      final model = WebhookModel.fromJson({
        'id': 'webhook-1',
        'channelId': 'channel-1',
        'name': 'Deploy alerts',
        'slug': 'deploy-alerts',
        'url': 'https://example.com/hooks/deploy',
        'isActive': true,
        'createdAt': '2026-11-04T07:30:00.000Z',
      });

      expect(model.id, 'webhook-1');
      expect(model.channelId, 'channel-1');
      expect(model.name, 'Deploy alerts');
      expect(model.slug, 'deploy-alerts');
      expect(model.url, 'https://example.com/hooks/deploy');
      expect(model.isActive, isTrue);
      expect(model.createdAt, DateTime.utc(2026, 11, 4, 7, 30));
    });

    test('parses the backend snake_case payload', () {
      final model = WebhookModel.fromJson({
        'id': 'webhook-2',
        'channel_id': 'channel-2',
        'name': 'Build alerts',
        'slug': 'build-alerts',
        'url': 'https://example.com/hooks/build',
        'is_active': 1,
        'created_at': '2026-11-04T08:00:00.000Z',
      });

      expect(model.channelId, 'channel-2');
      expect(model.isActive, isTrue);
      expect(model.createdAt, DateTime.utc(2026, 11, 4, 8));
    });

    test('falls back for missing optional fields', () {
      final model = WebhookModel.fromJson({'id': 'webhook-3'});

      expect(model.channelId, isEmpty);
      expect(model.name, isEmpty);
      expect(model.slug, isEmpty);
      expect(model.url, isEmpty);
      expect(model.isActive, isFalse);
      expect(model.createdAt, isNull);
    });

    test('round-trips through toJson', () {
      final original = WebhookModel(
        id: 'webhook-4',
        channelId: 'channel-4',
        name: 'Ops alerts',
        slug: 'ops-alerts',
        url: 'https://example.com/hooks/ops',
        isActive: true,
        createdAt: DateTime.utc(2026, 11, 4, 9, 15),
      );

      final restored = WebhookModel.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.channelId, original.channelId);
      expect(restored.name, original.name);
      expect(restored.slug, original.slug);
      expect(restored.url, original.url);
      expect(restored.isActive, original.isActive);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
