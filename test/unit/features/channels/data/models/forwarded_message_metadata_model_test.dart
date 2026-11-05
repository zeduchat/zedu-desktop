import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('ForwardedMessageMetadataModel', () {
    test('parses camelCase JSON', () {
      final model = ForwardedMessageMetadataModel.fromJson({
        'originalMessageId': 'msg-1',
        'originalSenderName': 'Ada',
        'originalChannelName': 'general',
        'originalCreatedAt': '2026-11-04T07:30:00.000Z',
        'isThread': true,
      });

      expect(model.originalMessageId, 'msg-1');
      expect(model.originalSenderName, 'Ada');
      expect(model.originalChannelName, 'general');
      expect(model.originalCreatedAt, DateTime.utc(2026, 11, 4, 7, 30));
      expect(model.isThread, isTrue);
    });

    test('parses backend snake_case JSON', () {
      final model = ForwardedMessageMetadataModel.fromJson({
        'original_message_id': 'msg-2',
        'original_sender_name': 'Grace',
        'original_channel_name': 'releases',
        'original_created_at': '2026-11-04T08:00:00.000Z',
        'is_thread': 1,
      });

      expect(model.originalMessageId, 'msg-2');
      expect(model.originalSenderName, 'Grace');
      expect(model.originalChannelName, 'releases');
      expect(model.originalCreatedAt, DateTime.utc(2026, 11, 4, 8));
      expect(model.isThread, isTrue);
    });

    test('defaults isThread and missing date safely', () {
      final model = ForwardedMessageMetadataModel.fromJson({
        'original_message_id': 'msg-3',
      });

      expect(model.originalSenderName, isEmpty);
      expect(model.originalChannelName, isEmpty);
      expect(model.originalCreatedAt, isNull);
      expect(model.isThread, isFalse);
    });

    test('round-trips through toJson', () {
      final original = ForwardedMessageMetadataModel(
        originalMessageId: 'msg-4',
        originalSenderName: 'Linus',
        originalChannelName: 'design',
        originalCreatedAt: DateTime.utc(2026, 11, 4, 9, 15),
        isThread: true,
      );

      final restored = ForwardedMessageMetadataModel.fromJson(
        original.toJson(),
      );

      expect(restored.originalMessageId, original.originalMessageId);
      expect(restored.originalSenderName, original.originalSenderName);
      expect(restored.originalChannelName, original.originalChannelName);
      expect(restored.originalCreatedAt, original.originalCreatedAt);
      expect(restored.isThread, original.isThread);
    });
  });
}
