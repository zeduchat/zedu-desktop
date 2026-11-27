class MagicLinkDeepLinkParser {
  const MagicLinkDeepLinkParser._();

  /// The magic-link token in [uri], or null when [uri] is not a link the app
  /// trusts.
  ///
  /// Web links must be `https` on one of [trustedWebHosts] exactly (see
  /// `trustedWebHosts(AppConfig)`), with no user info and the default port.
  /// Any other site could otherwise publish a link with the right path and
  /// have the app send its token to the backend.
  static String? extractToken(Uri uri, {required Set<String> trustedWebHosts}) {
    if (!_isSupportedMagicLinkUri(uri, trustedWebHosts)) return null;
    final token = uri.queryParameters['token']?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static bool _isSupportedMagicLinkUri(Uri uri, Set<String> trustedWebHosts) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = _normalizePath(uri.path);

    if (scheme == 'zedu' && host == 'auth' && path == '/magick-link/verify') {
      return true;
    }

    if (scheme == 'https' &&
        _isTrustedWebOrigin(uri, host, trustedWebHosts) &&
        path.endsWith('/auth/magick-link/verify')) {
      return true;
    }

    return false;
  }

  static bool _isTrustedWebOrigin(
    Uri uri,
    String host,
    Set<String> trustedWebHosts,
  ) {
    if (uri.userInfo.isNotEmpty) return false;
    // `Uri.hasPort` is false for the scheme's default port (443 for https).
    if (uri.hasPort) return false;
    return trustedWebHosts.contains(host);
  }

  static String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '/';
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }
}
