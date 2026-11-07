import 'package:zedu/core/core.dart';

/// Default Google OAuth client id for the **desktop** client type; it applies
/// whenever `GOOGLE_CLIENT_ID` comes from neither `--dart-define` nor `.env`.
///
/// This is the id the app actually runs with: the locator registers
/// [AppConfig.fromEnvironment], whose fallback reads this constant, and the
/// [AppConfig] constructor default reads it too, so direct construction and
/// environment resolution can never disagree. For reference, the **web**
/// client id used by browser builds is
/// `764182056638-bi8bet0rdoabaeq24bqsdnb5iukn7ko4.apps.googleusercontent.com`.
const String kDefaultDesktopGoogleClientId =
    '764182056638-08g88e196e643mhpa2tuv5dpr7iumd1j.apps.googleusercontent.com';

/// Zedu's staging API host. Debug and profile builds fall back to it, so local
/// development never writes to production by accident.
const String kStagingApiBaseUrl = 'https://api.staging.zedu.chat/api/v1/';

/// Zedu's production API host. Release builds fall back to it, so a shipped
/// build that omits `API_BASE_URL` cannot silently talk to staging.
const String kProductionApiBaseUrl = 'https://api.zedu.chat/api/v1/';

/// The API host used when neither `--dart-define` nor `.env` supplies one.
///
/// Release builds default to production; debug and profile builds default to
/// staging. Keeping the choice in one function makes it testable without
/// rebuilding in release mode.
String defaultApiBaseUrl({required bool isRelease}) =>
    isRelease ? kProductionApiBaseUrl : kStagingApiBaseUrl;

/// The website's Contact Sales page, opened from the Enterprise plan.
const String kDefaultContactSalesUrl = 'https://zedu.chat/contact-sales';

/// Where in-app reports of messages and people go, until the backend has a
/// report endpoint.
const String kReportEmail = 'support@emerj.net';

/// The live Centrifugo websocket, used when `CONNECT_URL` comes from neither
/// `--dart-define` nor `.env`. It carries realtime events such as incoming
/// Buzz calls; the web app reads the same URL from `NEXT_PUBLIC_CONNECT_URL`.
const String kDefaultConnectUrl =
    'wss://api.zedu.chat/centrifugo/connection/websocket';

/// Default repository URL for the Zedu Desktop app.
const String kDefaultRepoUrl = 'https://github.com/zeduchat/zedu-desktop';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.usesMockData,
    this.googleClientId = kDefaultDesktopGoogleClientId,
    this.googleClientSecret = '',
    this.contactSalesUrl = kDefaultContactSalesUrl,
    this.webAppUrl = '',
    this.repoUrl = kDefaultRepoUrl,
    this.repoUrls = const <String>[],
    this.connectUrl = kDefaultConnectUrl,
  });

  /// Whether [url] matches one of the repository URLs this project accepts
  /// for PR deliveries. Returns true when the repo list is empty (meaning any
  /// repo is accepted), or when [url] matches one of the configured URLs.
  bool isValidRepoUrl(String url) {
    if (repoUrls.isEmpty) return true;
    final normalized = url.replaceAll('"', '').replaceAll("'", '').trim();
    return repoUrls.any((u) {
      final normalizedRepo = u.replaceAll('"', '').replaceAll("'", '').trim();
      final normalizedRepoNoSlash = normalizedRepo.endsWith('/')
          ? normalizedRepo.substring(0, normalizedRepo.length - 1)
          : normalizedRepo;
      return normalized == normalizedRepoNoSlash ||
          '$normalizedRepoNoSlash/'.startsWith(normalized) ||
          '$normalized/'.startsWith(normalizedRepoNoSlash);
    });
  }

  /// Resolves config after [loadAppEnv] has run in [main] (root `.env` /
  /// `.env.example`, bundled as assets).
  ///
  /// Precedence: `--dart-define` wins, then dotenv keys from those files, then
  /// the build-mode default from [defaultApiBaseUrl]: staging for debug and
  /// profile builds, production for release builds. See [String.fromEnvironment](https://api.flutter.dev/flutter/dart-ui/String/String.fromEnvironment.html).
  factory AppConfig.fromEnvironment() {
    const defineApiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const defineUsesMock = String.fromEnvironment('USE_MOCK_DATA');
    const defineClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    const defineClientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');
    const defineWebAppUrl = String.fromEnvironment('WEB_APP_URL');
    const defineRepoUrl = String.fromEnvironment('REPO_URL');
    const defineRepoUrls = String.fromEnvironment('REPO_URLS');
    const defineConnectUrl = String.fromEnvironment('CONNECT_URL');

    final envApiBaseUrl = dotenv.maybeGet('API_BASE_URL')?.trim();
    final envUsesMock = dotenv.maybeGet('USE_MOCK_DATA')?.trim();
    final envClientId = dotenv.maybeGet('GOOGLE_CLIENT_ID')?.trim();
    final envClientSecret = dotenv.maybeGet('GOOGLE_CLIENT_SECRET')?.trim();
    final envWebAppUrl = dotenv.maybeGet('WEB_APP_URL')?.trim();
    final envRepoUrl = dotenv.maybeGet('REPO_URL')?.trim();
    final envRepoUrls = dotenv.maybeGet('REPO_URLS')?.trim();
    final envConnectUrl = dotenv.maybeGet('CONNECT_URL')?.trim();

    // Teams point the app at their own backend via --dart-define or .env;
    // otherwise the build mode decides, so release builds never default to
    // staging.
    String apiBaseUrl = defineApiBaseUrl.isNotEmpty
        ? defineApiBaseUrl
        : (envApiBaseUrl?.isNotEmpty ?? false)
        ? envApiBaseUrl!
        : defaultApiBaseUrl(isRelease: kReleaseMode);

    apiBaseUrl = apiBaseUrl.replaceAll('"', '').replaceAll("'", "");

    if (!apiBaseUrl.endsWith('/')) {
      apiBaseUrl += '/';
    }

    final usesMockData = defineUsesMock.isNotEmpty
        ? _parseBool(defineUsesMock, defaultValue: false)
        : envUsesMock != null && envUsesMock.isNotEmpty
        ? _parseBool(envUsesMock, defaultValue: false)
        : false; // Changed to false so real backend is used by default

    final googleClientId = defineClientId.isNotEmpty
        ? defineClientId
        : (envClientId?.isNotEmpty ?? false)
        ? envClientId!
        : kDefaultDesktopGoogleClientId;

    final googleClientSecret = defineClientSecret.isNotEmpty
        ? defineClientSecret
        : (envClientSecret?.isNotEmpty ?? false)
        ? envClientSecret!
        : '';

    // Build the list of accepted repository URLs: the explicit repo URL plus
    // any additional comma-separated URLs from REPO_URLS.
    List<String> repoUrls = <String>[];
    final repoUrl = defineRepoUrl.isNotEmpty
        ? defineRepoUrl
        : (envRepoUrl?.isNotEmpty ?? false)
        ? envRepoUrl!
        : kDefaultRepoUrl;
    if (defineRepoUrls.isNotEmpty) {
      repoUrls.addAll(
        defineRepoUrls
            .split(',')
            .map((u) => u.trim())
            .where((u) => u.isNotEmpty),
      );
    }
    if (envRepoUrls?.isNotEmpty ?? false) {
      repoUrls.addAll(
        envRepoUrls!.split(',').map((u) => u.trim()).where((u) => u.isNotEmpty),
      );
    }
    repoUrls.add(repoUrl);
    repoUrls = repoUrls.toSet().toList(); // Deduplicate
    final connectUrl = defineConnectUrl.isNotEmpty
        ? defineConnectUrl
        : (envConnectUrl?.isNotEmpty ?? false)
        ? envConnectUrl!
        : kDefaultConnectUrl;

    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      usesMockData: usesMockData,
      googleClientId: googleClientId,
      googleClientSecret: googleClientSecret,
      webAppUrl: defineWebAppUrl.isNotEmpty
          ? defineWebAppUrl
          : envWebAppUrl ?? '',
      repoUrl: repoUrl,
      repoUrls: repoUrls,
      connectUrl: connectUrl,
    );
  }

  final String apiBaseUrl;
  final bool usesMockData;
  final String googleClientId;
  final String googleClientSecret;
  final String contactSalesUrl;

  /// The web app's address, from `WEB_APP_URL`. Empty means [webBaseUrl]
  /// works it out from [apiBaseUrl].
  final String webAppUrl;

  /// The repository URL this project's PRs should target. Defaults to the
  /// Zedu Desktop GitHub repo. When set, PR deliveries are validated against
  // this URL (and any additional [repoUrls]).
  final String repoUrl;

  /// Additional repository URLs that are accepted for PR deliveries, in
  // addition to [repoUrl]. Used when a project's fixes span multiple
  // repositories (e.g., a desktop app and its backend).
  final List<String> repoUrls;

  /// Where the web app runs, without a trailing slash, for links that open
  /// in the browser (such as Buzz meetings). Defaults to the API host
  /// without its `api.` prefix: `https://api.zedu.chat/api/v1/` gives
  /// `https://zedu.chat`.
  String get webBaseUrl {
    final configured = webAppUrl.replaceAll('"', '').replaceAll("'", '').trim();
    if (configured.isNotEmpty) {
      return configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
    }
    final api = Uri.tryParse(apiBaseUrl);
    if (api == null || api.host.isEmpty) return 'https://zedu.chat';
    final host = api.host.startsWith('api.') ? api.host.substring(4) : api.host;
    return Uri(
      scheme: api.scheme.isEmpty ? 'https' : api.scheme,
      host: host,
      port: api.hasPort ? api.port : null,
    ).toString();
  }

  /// Centrifugo websocket for realtime events (`CONNECT_URL`).
  final String connectUrl;
}

bool _parseBool(String raw, {required bool defaultValue}) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return defaultValue;
}
