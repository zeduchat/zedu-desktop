/// Parses and builds `zedu://chat/<channelId>?message=<messageId>` deep links,
/// the links the message menu's "Copy link" action puts on the clipboard.
class ChatDeepLinkParser {
  const ChatDeepLinkParser._();

  static ({String channelId, String? messageId})? extractTarget(Uri uri) {
    if (uri.scheme.toLowerCase() != 'zedu' ||
        uri.host.toLowerCase() != 'chat') {
      return null;
    }
    final segments = uri.pathSegments
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return null;
    final channelId = segments.first;
    if (channelId.isEmpty) return null;
    final rawMessageId = uri.queryParameters['message']?.trim() ?? '';
    return (
      channelId: channelId,
      messageId: rawMessageId.isEmpty ? null : rawMessageId,
    );
  }

  static Uri buildUri(String channelId, {String? messageId}) => Uri(
    scheme: 'zedu',
    host: 'chat',
    path: '/$channelId',
    queryParameters: (messageId == null || messageId.isEmpty)
        ? null
        : {'message': messageId},
  );
}
