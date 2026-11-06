import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('ChatDeepLinkParser.extractTarget', () {
    test('parses a channel with a message id', () {
      final target = ChatDeepLinkParser.extractTarget(
        Uri.parse('zedu://chat/ch-42?message=m-7'),
      );
      expect(target, isNotNull);
      expect(target!.channelId, 'ch-42');
      expect(target.messageId, 'm-7');
    });

    test('parses a channel without a message id', () {
      final target = ChatDeepLinkParser.extractTarget(
        Uri.parse('zedu://chat/ch-42'),
      );
      expect(target, isNotNull);
      expect(target!.channelId, 'ch-42');
      expect(target.messageId, isNull);
    });

    test('ignores an empty message query param', () {
      final target = ChatDeepLinkParser.extractTarget(
        Uri.parse('zedu://chat/ch-42?message='),
      );
      expect(target!.messageId, isNull);
    });

    test('keeps extra path segments out of the channel id', () {
      final target = ChatDeepLinkParser.extractTarget(
        Uri.parse('zedu://chat/ch-42/extra'),
      );
      expect(target!.channelId, 'ch-42');
    });

    test('rejects non-chat links', () {
      expect(
        ChatDeepLinkParser.extractTarget(Uri.parse('zedu://auth/magic')),
        isNull,
      );
      expect(
        ChatDeepLinkParser.extractTarget(Uri.parse('https://zedu.chat/chat/c')),
        isNull,
      );
      expect(
        ChatDeepLinkParser.extractTarget(Uri.parse('zedu://chat')),
        isNull,
      );
      expect(
        ChatDeepLinkParser.extractTarget(Uri.parse('zedu://chat/')),
        isNull,
      );
    });
  });

  group('ChatDeepLinkParser.buildUri', () {
    test('builds a link with a message id', () {
      final uri = ChatDeepLinkParser.buildUri('ch-42', messageId: 'm-7');
      expect(uri.toString(), 'zedu://chat/ch-42?message=m-7');
    });

    test('builds a link without the query when there is no message id', () {
      final uri = ChatDeepLinkParser.buildUri('ch-42');
      expect(uri.toString(), 'zedu://chat/ch-42');
    });

    test('round-trips through extractTarget', () {
      final uri = ChatDeepLinkParser.buildUri('ch-1', messageId: 'm-2');
      final target = ChatDeepLinkParser.extractTarget(uri);
      expect(target!.channelId, 'ch-1');
      expect(target.messageId, 'm-2');
    });
  });
}
