/// Desktop's side of the `zeduDesktop` JavaScript handler that Office calls
/// from inside the WebView (see office-zedu-fe `desktop-bridge.ts`).
///
/// - `{type: 'getZeduToken'}` answers `{token, apiUrl}`: this app's zedu
///   session and the zedu-be it belongs to, so Office signs in without a
///   second login.
/// - `{type: 'exit'}` closes Office and returns to the app.
///
/// The session is only handed to a page on Office's own origin, so a link
/// that strays to another site inside the WebView never receives it.
class OfficeBridge {
  OfficeBridge({
    required this.officeUrl,
    required this.apiUrl,
    required this.readToken,
    required this.onExit,
  });

  static const handlerName = 'zeduDesktop';

  final String officeUrl;
  final String apiUrl;
  final Future<String?> Function() readToken;
  final void Function() onExit;

  /// Whether [url] is a page of Office itself.
  bool isOfficePage(Uri? url) {
    final office = Uri.tryParse(officeUrl);
    if (url == null || office == null) return false;
    return url.scheme == office.scheme &&
        url.host == office.host &&
        url.port == office.port;
  }

  /// Answers one handler call made from [pageUrl].
  Future<Map<String, String>?> handle(List<dynamic> args, Uri? pageUrl) async {
    final message = args.isEmpty ? null : args.first;
    final type = message is Map ? message['type'] : null;

    switch (type) {
      case 'getZeduToken':
        if (!isOfficePage(pageUrl)) return null;
        final token = await readToken();
        if (token == null || token.isEmpty) return null;
        return {'token': token, 'apiUrl': apiUrl};
      case 'exit':
        onExit();
        return null;
      default:
        return null;
    }
  }
}
