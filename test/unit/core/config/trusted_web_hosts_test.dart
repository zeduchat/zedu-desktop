import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  AppConfig config(String api, {String web = ''}) =>
      AppConfig(apiBaseUrl: api, usesMockData: false, webAppUrl: web);

  group('trustedWebHosts', () {
    test('is the host of the configured web app', () {
      expect(
        trustedWebHosts(
          config(
            'https://api.zedu.chat/api/v1/',
            web: 'https://App.Zedu.chat/',
          ),
        ),
        {'app.zedu.chat'},
      );
    });

    test('falls back to the web host derived from the API', () {
      expect(trustedWebHosts(config('https://api.zedu.chat/api/v1/')), {
        'zedu.chat',
      });
      expect(trustedWebHosts(config('https://api.staging.zedu.chat/api/v1/')), {
        'staging.zedu.chat',
      });
    });
  });
}
