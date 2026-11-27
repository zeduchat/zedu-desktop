import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

Map<String, dynamic> _json({String? lastReadAt}) => {
  'channel_id': 'dm-1',
  'username': 'Ada',
  'participant_id': 'user-1',
  'preview_message': '',
  'last_read_at': lastReadAt,
};

void main() {
  group('DmConversation.lastReadAt', () {
    test('treats the Go zero timestamp as no activity', () {
      final conversation = DmConversation.fromJson(
        _json(lastReadAt: '0001-01-01T00:00:00Z'),
      );

      expect(conversation.lastReadAt, isNull);
      expect(conversation.hasActivity, isFalse);
      expect(
        conversation.lastActivityAt,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });

    test('treats a null last_read_at as no activity', () {
      final conversation = DmConversation.fromJson(_json());

      expect(conversation.lastReadAt, isNull);
      expect(conversation.hasActivity, isFalse);
    });

    test('treats the 1970 placeholder as no activity', () {
      final conversation = DmConversation.fromJson(
        _json(lastReadAt: '1970-01-01T00:00:00Z'),
      );

      expect(conversation.lastReadAt, isNull);
      expect(conversation.hasActivity, isFalse);
    });

    test('keeps a real last read timestamp', () {
      final conversation = DmConversation.fromJson(
        _json(lastReadAt: '2026-11-05T08:00:00Z'),
      );

      expect(conversation.lastReadAt, isNotNull);
      expect(conversation.lastReadAt!.toUtc(), DateTime.utc(2026, 11, 5, 8));
      expect(conversation.hasActivity, isTrue);
    });
  });

  group('DmPreviewThread.created_at', () {
    Map<String, dynamic> withCreatedAt(Object? createdAt) => {
      ..._json(),
      'preview_thread': [
        {
          'thread_id': 't-1',
          'message': 'hi',
          'user_id': 'user-1',
          'username': 'Ada',
          'created_at': createdAt,
        },
      ],
    };

    for (final bad in <Object?>['', 'not-a-date', 12345]) {
      test('falls back to now for ${bad.runtimeType} "$bad"', () {
        final before = DateTime.now();
        final conversation = DmConversation.fromJson(withCreatedAt(bad));
        final after = DateTime.now();

        final createdAt = conversation.previewThreads.single.createdAt;
        expect(createdAt.isBefore(before), isFalse);
        expect(createdAt.isAfter(after), isFalse);
      });
    }

    test('keeps a valid timestamp', () {
      final conversation = DmConversation.fromJson(
        withCreatedAt('2026-11-05T08:00:00Z'),
      );

      expect(
        conversation.previewThreads.single.createdAt.toUtc(),
        DateTime.utc(2026, 11, 5, 8),
      );
    });
  });
}
