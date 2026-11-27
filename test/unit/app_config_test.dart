import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('AppConfig googleClientId defaults', () {
    setUpAll(() {
      // Mirror an empty/absent `.env` value so fromEnvironment can read
      // dotenv keys and still fall through to the built-in default.
      dotenv.loadFromString(envString: 'GOOGLE_CLIENT_ID=');
    });

    test(
      'constructor default and fromEnvironment fallback are the same id',
      () {
        const direct = AppConfig(
          apiBaseUrl: 'https://example.com/',
          usesMockData: false,
        );
        final viaEnvironment = AppConfig.fromEnvironment();

        expect(direct.googleClientId, kDefaultDesktopGoogleClientId);
        expect(
          viaEnvironment.googleClientId,
          direct.googleClientId,
          reason:
              'AppConfig() and AppConfig.fromEnvironment() must resolve to '
              'the same default desktop Google client id',
        );
      },
    );
  });

  group('AppConfig API host default', () {
    setUpAll(() {
      // Mirror an absent `API_BASE_URL` so fromEnvironment has to fall back.
      dotenv.loadFromString(envString: 'API_BASE_URL=');
    });

    test('release builds default to the production host', () {
      expect(defaultApiBaseUrl(isRelease: true), kProductionApiBaseUrl);
      expect(kProductionApiBaseUrl, 'https://api.zedu.chat/api/v1/');
    });

    test('debug and profile builds default to staging', () {
      expect(defaultApiBaseUrl(isRelease: false), kStagingApiBaseUrl);
      expect(kStagingApiBaseUrl, 'https://api.staging.zedu.chat/api/v1/');
    });

    test('fromEnvironment uses the build-mode default', () {
      final config = AppConfig.fromEnvironment();

      expect(config.apiBaseUrl, defaultApiBaseUrl(isRelease: kReleaseMode));
    });
  });

  group('AppConfig Google client secret', () {
    const leaked = 'leaked-google-client-secret';

    setUpAll(() {
      // A stale `.env` that still carries a client secret must not feed it
      // into the app: desktop Google sign-in sends only the client id and
      // the backend does the token exchange.
      dotenv.loadFromString(
        envString: 'GOOGLE_CLIENT_ID=\nGOOGLE_CLIENT_SECRET=$leaked',
      );
    });

    test('fromEnvironment ignores GOOGLE_CLIENT_SECRET from .env', () {
      final config = AppConfig.fromEnvironment();

      final values = <String>[
        config.apiBaseUrl,
        config.googleClientId,
        config.contactSalesUrl,
        config.webAppUrl,
        config.webBaseUrl,
        config.repoUrl,
        ...config.repoUrls,
        config.connectUrl,
      ];
      expect(values, everyElement(isNot(contains(leaked))));
      expect(config.googleClientId, kDefaultDesktopGoogleClientId);
    });

    test('.env.example no longer asks for a client secret', () {
      final template = File('.env.example').readAsStringSync();

      expect(template, isNot(contains('GOOGLE_CLIENT_SECRET')));
    });
  });
}
