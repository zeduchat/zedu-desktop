class MagicLinkDeepLinkParser {
  const MagicLinkDeepLinkParser._();

  /// Paths under `/auth` that carry a magic-link token: the web login route
  /// the backend puts in the email, its short alias, and the verify route.
  static const _authPaths = {
    '/login/magic-link',
    '/magiclink',
    '/magick-link/verify',
  };

  static String? extractToken(Uri uri) {
    if (!_isSupportedMagicLinkUri(uri)) return null;
    final token = uri.queryParameters['token']?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static bool _isSupportedMagicLinkUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = _normalizePath(uri.path);

    if (scheme == 'zedu' && host == 'auth' && _authPaths.contains(path)) {
      return true;
    }

    if ((scheme == 'https' || scheme == 'http') &&
        _authPaths.any((authPath) => path.endsWith('/auth$authPath'))) {
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
