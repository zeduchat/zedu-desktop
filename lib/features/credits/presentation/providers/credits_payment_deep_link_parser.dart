class CreditsPaymentDeepLinkParser {
  const CreditsPaymentDeepLinkParser._();

  /// Dummy redirect URI — replace when backend confirms production URL.
  static const dummySuccessUri =
      'zedu://credits/payment-success?session_id=cs_test_placeholder';

  /// Returns the payment session in [uri], or null when [uri] is not a
  /// payment callback the app trusts.
  ///
  /// Accepts `zedu://credits/payment-success`, and https links to
  /// `/credits/payment-success` on a host in [trustedWebHosts] (exact match,
  /// default port, no userinfo).
  static String? extractSessionId(
    Uri uri, {
    required Set<String> trustedWebHosts,
  }) {
    if (!_isSupportedPaymentUri(uri, trustedWebHosts)) return null;
    final sessionId = uri.queryParameters['session_id']?.trim();
    if (sessionId == null || sessionId.isEmpty) return null;
    return sessionId;
  }

  static bool _isSupportedPaymentUri(Uri uri, Set<String> trustedWebHosts) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = _normalizePath(uri.path);

    if (scheme == 'zedu' && host == 'credits' && path == '/payment-success') {
      return true;
    }

    if (scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        trustedWebHosts.contains(host) &&
        path.endsWith('/credits/payment-success')) {
      return true;
    }

    return false;
  }

  static String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '/';
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }
}
