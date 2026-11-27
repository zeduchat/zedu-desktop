import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('MagicLinkDeepLinkParser', () {
    const trusted = {'zedu.chat'};

    String? extract(String link) => MagicLinkDeepLinkParser.extractToken(
      Uri.parse(link),
      trustedWebHosts: trusted,
    );

    test('extracts token from custom zedu scheme link', () {
      expect(extract('zedu://auth/magick-link/verify?token=abc123'), 'abc123');
    });

    test('extracts token from an https link on a trusted host', () {
      expect(
        extract('https://zedu.chat/auth/magick-link/verify?token=abc123'),
        'abc123',
      );
      expect(
        extract('https://ZEDU.chat/auth/magick-link/verify?token=abc123'),
        'abc123',
      );
      expect(
        extract('https://zedu.chat:443/auth/magick-link/verify?token=abc123'),
        'abc123',
      );
    });

    test('returns null for missing token query parameter', () {
      expect(extract('zedu://auth/magick-link/verify'), isNull);
    });

    test('returns null for unsupported path', () {
      expect(extract('zedu://auth/magick-link?token=abc123'), isNull);
    });

    group('rejects (Ziki #2482)', () {
      final rejected = {
        'http on a trusted host':
            'http://zedu.chat/auth/magick-link/verify?token=abc123',
        'an untrusted host with the right path':
            'https://attacker.example/auth/magick-link/verify?token=abc123',
        'a host that only ends with the trusted host':
            'https://evilzedu.chat/auth/magick-link/verify?token=abc123',
        'a subdomain of the trusted host':
            'https://app.zedu.chat/auth/magick-link/verify?token=abc123',
        'the trusted host as a prefix of another domain':
            'https://zedu.chat.evil.com/auth/magick-link/verify?token=abc123',
        'user info before the trusted host':
            'https://user@zedu.chat/auth/magick-link/verify?token=abc123',
        'a non-default port':
            'https://zedu.chat:8443/auth/magick-link/verify?token=abc123',
        'another scheme':
            'ftp://zedu.chat/auth/magick-link/verify?token=abc123',
      };

      rejected.forEach((reason, link) {
        test(reason, () => expect(extract(link), isNull));
      });

      test('any web link when no host is trusted', () {
        expect(
          MagicLinkDeepLinkParser.extractToken(
            Uri.parse('https://zedu.chat/auth/magick-link/verify?token=abc'),
            trustedWebHosts: const {},
          ),
          isNull,
        );
      });
    });
  });
}
