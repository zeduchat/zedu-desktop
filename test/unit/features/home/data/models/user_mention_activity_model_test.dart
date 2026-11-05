import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('UserMentionActivityModel', () {
    test('parses a camelCase mention', () {
      final model = UserMentionActivityModel.fromJson({
        'id': 'mention-1',
        'messageId': 'msg-1',
        'channelId': 'channel-1',
        'channelName': 'general',
        'senderName': 'Ada',
        'senderAvatarUrl': 'https://cdn.example.com/ada.png',
        'content': '@Arnold please review',
        'createdAt': '2026-11-04T07:30:00.000Z',
      });

      expect(model.id, 'mention-1');
      expect(model.messageId, 'msg-1');
      expect(model.channelId, 'channel-1');
      expect(model.channelName, 'general');
      expect(model.senderName, 'Ada');
      expect(model.senderAvatarUrl, 'https://cdn.example.com/ada.png');
      expect(model.content, '@Arnold please review');
      expect(model.createdAt, DateTime.utc(2026, 11, 4, 7, 30));
    });

    test('parses the backend snake_case mention', () {
      final model = UserMentionActivityModel.fromJson({
        'id': 'mention-2',
        'message_id': 'msg-2',
        'channel_id': 'channel-2',
        'channel_name': 'releases',
        'sender_name': 'Grace',
        'sender_avatar_url': '',
        'content': '@Arnold ship it',
        'created_at': '2026-11-04T08:00:00.000Z',
      });

      expect(model.messageId, 'msg-2');
      expect(model.senderName, 'Grace');
      expect(model.senderAvatarUrl, isNull);
      expect(model.createdAt, DateTime.utc(2026, 11, 4, 8));
    });

    test('falls back for missing optional fields', () {
      final model = UserMentionActivityModel.fromJson({'id': 'mention-3'});

      expect(model.messageId, isEmpty);
      expect(model.channelId, isEmpty);
      expect(model.channelName, isEmpty);
      expect(model.senderName, isEmpty);
      expect(model.content, isEmpty);
      expect(model.senderAvatarUrl, isNull);
      expect(model.createdAt, isNull);
    });

    test('round-trips through toJson', () {
      final original = UserMentionActivityModel(
        id: 'mention-4',
        messageId: 'msg-4',
        channelId: 'channel-4',
        channelName: 'design',
        senderName: 'Linus',
        senderAvatarUrl: 'https://cdn.example.com/linus.png',
        content: '@Arnold mockup ready',
        createdAt: DateTime.utc(2026, 11, 4, 9, 15),
      );

      final restored = UserMentionActivityModel.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.messageId, original.messageId);
      expect(restored.channelId, original.channelId);
      expect(restored.channelName, original.channelName);
      expect(restored.senderName, original.senderName);
      expect(restored.senderAvatarUrl, original.senderAvatarUrl);
      expect(restored.content, original.content);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
