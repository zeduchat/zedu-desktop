import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('AppNotification.fromJson (Ziki #33700)', () {
    test('reads a DM notification and its payload like zedu-fe', () {
      final item = AppNotification.fromJson({
        'id': 'n1',
        'title': 'Jemi',
        'message': 'Estimate done',
        'sent_at': '2026-11-26T17:31:00Z',
        'payload': {
          'notification_type': 'dm',
          'channel_id': 'c1',
          'sender_id': 'u2',
          'sender_name': 'Jemi A.',
          'avatar_url': 'https://cdn.zedu.test/jemi.png',
        },
      });

      expect(item.id, 'n1');
      expect(item.kind, AppNotificationKind.directMessage);
      expect(item.isDirect, isTrue);
      expect(item.participantId, 'u2');
      expect(item.displaySender, 'Jemi A.');
      expect(item.avatarUrl, 'https://cdn.zedu.test/jemi.png');
      expect(item.typeLabel, 'Direct message');
      expect(item.sentAt, DateTime.utc(2026, 11, 26, 17, 31).toLocal());
      expect(item.canOpen, isTrue);
    });

    test('reads a channel mention from a JSON-string payload', () {
      final item = AppNotification.fromJson({
        'id': 7,
        'title': '#saviour',
        'message': '@Emmanuel need you to help estimate this too',
        'created_at': 1764178320,
        'data':
            '{"notification_type":"mention","channel_id":"ch9",'
            '"channel_name":"saviour"}',
      });

      expect(item.id, '7');
      expect(item.kind, AppNotificationKind.channel);
      expect(item.typeLabel, 'Mention');
      expect(item.channelName, 'saviour');
      expect(
        item.sentAt,
        DateTime.fromMillisecondsSinceEpoch(1764178320 * 1000),
      );
    });

    test('a group DM is recognised from its channel type', () {
      final item = AppNotification.fromJson({
        'id': 'g',
        'title': 'Team',
        'message': 'hi',
        'payload': {'channel_type': 'group_dm', 'channel_id': 'gc'},
      });

      expect(item.kind, AppNotificationKind.groupDirectMessage);
    });

    test('the server read flag is kept', () {
      expect(
        AppNotification.fromJson({
          'id': 'r',
          'title': 't',
          'message': 'm',
          'is_read': true,
        }).serverRead,
        isTrue,
      );
    });
  });
}
