import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('SearchResultModel', () {
    test('parses a flat camelCase payload', () {
      final model = SearchResultModel.fromJson({
        'id': 'msg-1',
        'content': 'hello team',
        'channelId': 'channel-1',
        'channelName': 'general',
        'senderName': 'Ada',
        'senderAvatarUrl': 'https://cdn.example.com/ada.png',
        'createdAt': '2026-11-04T07:30:00.000Z',
      });

      expect(model.id, 'msg-1');
      expect(model.content, 'hello team');
      expect(model.channelId, 'channel-1');
      expect(model.channelName, 'general');
      expect(model.senderName, 'Ada');
      expect(model.senderAvatarUrl, 'https://cdn.example.com/ada.png');
      expect(model.createdAt, DateTime.utc(2026, 11, 4, 7, 30));
    });

    test('parses the backend snake_case payload', () {
      final model = SearchResultModel.fromJson({
        'message_id': 'msg-2',
        'message': 'ship it',
        'channel_id': 'channel-2',
        'channel_name': 'releases',
        'user_name': 'Grace',
        'avatar_url': 'https://cdn.example.com/grace.png',
        'timestamp': '2026-11-04T08:00:00.000Z',
      });

      expect(model.id, 'msg-2');
      expect(model.content, 'ship it');
      expect(model.channelId, 'channel-2');
      expect(model.channelName, 'releases');
      expect(model.senderName, 'Grace');
      expect(model.senderAvatarUrl, 'https://cdn.example.com/grace.png');
      expect(model.createdAt, DateTime.utc(2026, 11, 4, 8));
    });

    test('falls back for missing optional fields', () {
      final model = SearchResultModel.fromJson({'id': 'msg-3'});

      expect(model.content, isEmpty);
      expect(model.channelId, isEmpty);
      expect(model.channelName, isEmpty);
      expect(model.senderName, isEmpty);
      expect(model.senderAvatarUrl, isNull);
      expect(model.createdAt, isNull);
    });

    test('round-trips through toJson', () {
      final original = SearchResultModel(
        id: 'msg-4',
        content: 'round trip',
        channelId: 'channel-4',
        channelName: 'design',
        senderName: 'Linus',
        senderAvatarUrl: 'https://cdn.example.com/linus.png',
        createdAt: DateTime.utc(2026, 11, 4, 9, 15),
      );

      final restored = SearchResultModel.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.content, original.content);
      expect(restored.channelId, original.channelId);
      expect(restored.channelName, original.channelName);
      expect(restored.senderName, original.senderName);
      expect(restored.senderAvatarUrl, original.senderAvatarUrl);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
