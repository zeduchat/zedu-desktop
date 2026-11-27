import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  const trusted = {'zedu.chat'};

  String? parse(String link) => CreditsPaymentDeepLinkParser.extractSessionId(
    Uri.parse(link),
    trustedWebHosts: trusted,
  );

  group('CreditsPaymentDeepLinkParser.extractSessionId', () {
    test('accepts the zedu scheme callback', () {
      expect(parse('zedu://credits/payment-success?session_id=cs-1'), 'cs-1');
    });

    test('accepts an https callback on a trusted host', () {
      expect(
        parse('https://zedu.chat/credits/payment-success?session_id=cs-1'),
        'cs-1',
      );
      expect(
        parse('https://ZEDU.chat/app/credits/payment-success?session_id=cs-2'),
        'cs-2',
      );
      expect(
        parse('https://zedu.chat:443/credits/payment-success?session_id=cs-3'),
        'cs-3',
      );
    });

    test('rejects an untrusted host using the payment path', () {
      expect(
        parse('https://evil.example/credits/payment-success?session_id=cs-1'),
        isNull,
      );
    });

    test('rejects lookalike and suffix hosts', () {
      for (final host in [
        'zedu.chat.evil.example',
        'evilzedu.chat',
        'app.zedu.chat',
        'zedu.chat.',
        'zedu-chat.com',
      ]) {
        expect(
          parse('https://$host/credits/payment-success?session_id=cs-1'),
          isNull,
          reason: host,
        );
      }
    });

    test('rejects http and other schemes on a trusted host', () {
      expect(
        parse('http://zedu.chat/credits/payment-success?session_id=cs-1'),
        isNull,
      );
      expect(
        parse('ftp://zedu.chat/credits/payment-success?session_id=cs-1'),
        isNull,
      );
    });

    test('rejects userinfo and non-default ports', () {
      expect(
        parse('https://user@zedu.chat/credits/payment-success?session_id=cs-1'),
        isNull,
      );
      expect(
        parse('https://zedu.chat:8443/credits/payment-success?session_id=cs-1'),
        isNull,
      );
    });

    test('rejects web links when no host is trusted', () {
      expect(
        CreditsPaymentDeepLinkParser.extractSessionId(
          Uri.parse(
            'https://zedu.chat/credits/payment-success?session_id=cs-1',
          ),
          trustedWebHosts: const {},
        ),
        isNull,
      );
    });

    test('rejects a trusted host with the wrong path or no session', () {
      expect(parse('https://zedu.chat/billing?session_id=cs-1'), isNull);
      expect(parse('https://zedu.chat/credits/payment-success'), isNull);
      expect(parse('zedu://credits/payment-success?session_id=%20'), isNull);
    });
  });
}
