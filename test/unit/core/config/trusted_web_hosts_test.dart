import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

void main() {
  AppConfig config(String api, {String web = ''}) =>
      AppConfig(apiBaseUrl: api, usesMockData: false, webAppUrl: web);

  test('is the web app host derived from the API host', () {
    expect(trustedWebHosts(config('https://api.zedu.chat/api/v1/')), {
      'zedu.chat',
    });
    expect(trustedWebHosts(config('https://api.staging.zedu.chat/api/v1/')), {
      'staging.zedu.chat',
    });
  });

  test('uses WEB_APP_URL when set, lower-cased', () {
    expect(
      trustedWebHosts(
        config('https://api.zedu.chat/api/v1/', web: 'https://Web.Team.test/'),
      ),
      {'web.team.test'},
    );
  });
}
