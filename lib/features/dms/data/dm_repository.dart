import 'dart:collection';
import 'dart:math' show Random;

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final dmRepositoryProvider = Provider<DmRepository>((ref) {
  final apiClient = locator<ApiBaseService>();
  return DmRepository(apiClient);
});

class DmConversationsPage with ListMixin<DmConversation> {
  final List<DmConversation> conversations;
  final int currentPage;
  final int totalPages;
  final int totalItems;

  const DmConversationsPage({
    required this.conversations,
    required this.currentPage,
    required this.totalPages,
    this.totalItems = 0,
  });

  @override
  int get length => conversations.length;

  @override
  set length(int newLength) => conversations.length = newLength;

  @override
  DmConversation operator [](int index) => conversations[index];

  @override
  void operator []=(int index, DmConversation value) =>
      conversations[index] = value;

  bool get hasMore => currentPage < totalPages;
}

class DmRepository {
  static const int pageSize = 20;

  final ApiBaseService _apiClient;

  DmRepository(this._apiClient);

  Future<DmConversationsPage> getConversations({
    required String orgId,
    int page = 1,
    bool recentDm = false,
    String? search,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      path: '/organisations/$orgId/dms',
      queryParameters: {
        'page': page,
        'limit': pageSize,
        'recent_dm': recentDm,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    final data = response.data;
    final rawList = data['data'];
    final list = (rawList is List ? rawList : const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(DmConversation.fromJson)
        .toList();

    list.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));

    var pagination = data['pagination'];
    if (pagination is List) {
      pagination = pagination.isEmpty ? null : pagination.first;
    }
    int? value(String key) => pagination is Map
        ? num.tryParse(pagination[key]?.toString() ?? '')?.toInt()
        : null;

    final currentPage = value('current_page') ?? page;
    final totalPages =
        value('total_pages') ??
        value('total_pages_count') ??
        (list.length >= pageSize ? currentPage + 1 : currentPage);
    final totalItems =
        value('total_items') ?? (page - 1) * pageSize + list.length;

    return DmConversationsPage(
      conversations: list,
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalItems: totalItems < 0 ? 0 : totalItems,
    );
  }

  /// Removes the DM from the caller's list on the server. The other
  /// participant keeps the conversation and its messages.
  Future<void> deleteConversation({
    required String orgId,
    required String channelId,
  }) async {
    await _apiClient.delete<Map<String, dynamic>>(
      path: '/organisations/$orgId/dms/$channelId',
    );
  }

  /// Searches the whole history of one conversation on the server, not just
  /// the messages loaded on screen.
  Future<List<ConversationSearchHit>> searchMessages({
    required String channelId,
    required String query,
  }) async {
    final trimmed = query.trim();
    if (channelId.isEmpty || trimmed.isEmpty) return const [];
    final response = await _apiClient.get<Map<String, dynamic>>(
      path: '/search/channel/$channelId',
      queryParameters: {'query': trimmed, 'sortBy': 'relevance'},
    );
    return ConversationSearchHit.fromResponse(response.data['data']);
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String channelId, {
    int page = 1,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      path: '/channels/$channelId/messages',
      queryParameters: {'page': page, 'limit': pageSize},
    );

    final data = response.data;
    final rawMessages = data['messages'] ?? data['data'];
    final messages = rawMessages is Map<String, dynamic>
        ? rawMessages['messages'] ?? rawMessages['data']
        : rawMessages;

    if (messages is! List) return const [];

    return messages
        .whereType<Map<dynamic, dynamic>>()
        .map((message) => Map<String, dynamic>.from(message))
        .toList();
  }

  /// Creates a group DM with [participantIds] on the server and returns its
  /// channel id, as Zedu web's New chat does.
  Future<String> createGroupDm({
    required String orgId,
    required List<String> participantIds,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      path: '/organisations/$orgId/group-dms',
      data: {'chat_type': 'user', 'participants': participantIds},
    );
    final data = response.data['data'];
    final channelId = data is Map ? '${data['channel_id'] ?? ''}'.trim() : '';
    if (channelId.isEmpty) {
      throw const FormatException('Invalid group DM response.');
    }
    return channelId;
  }

  /// Opens (or creates) the direct message with [participantId].
  Future<({String channelId, String participantId})> openConversation({
    required String orgId,
    required String participantId,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      path: '/organisations/$orgId/dms',
      data: {'chat_type': 'user', 'participant_id': participantId},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final channelId = data['channel_id'] as String;
    final openedParticipantId = data['participant_id'] as String;
    if (channelId.isEmpty || openedParticipantId.isEmpty) {
      throw const FormatException('Invalid direct message response.');
    }
    return (channelId: channelId, participantId: openedParticipantId);
  }

  /// Sends a message and returns the thread id it was created with, which the
  /// delete endpoint needs.
  Future<String> sendMessage(
    String channelId,
    String content, {
    List<XFile>? media,
    List<dynamic>? mentions,
    bool isChannel = false,
  }) async {
    // Files are uploaded first (same as the web app); the message then
    // carries the file details the server returns, not a local file path.
    final uploaded = media != null && media.isNotEmpty
        ? await _uploadFiles(media)
        : const <Map<String, dynamic>>[];

    // The server requires a thread_id; like the web app, a new message
    // starts its own thread with a fresh UUID v7.
    final threadId = _newUuidV7();
    final sendResponse = await _apiClient.post<Map<String, dynamic>>(
      // A direct message is not an ordinary channel on the server: like the
      // web app, it is posted to the DM route, not /channels/:id/messages.
      path: isChannel
          ? '/threads/$channelId'
          : '/dms/channels/$channelId/threads',
      data: {
        // The server rejects an empty content, so a voice note or file sent
        // without text carries an empty paragraph, like the web composer.
        "content": content.isEmpty && uploaded.isNotEmpty ? '<p></p>' : content,
        "thread_id": threadId,
        if (uploaded.isNotEmpty) "media": uploaded,
        ...?(mentions != null ? {'mentions': mentions} : null),
      },
    );
    // The server keeps its own id for the thread it creates, not the one sent,
    // and the delete and edit routes need that one.
    final created = sendResponse.data['data'];
    final createdThreadId = created is Map ? created['thread_id'] : null;
    return createdThreadId is String && createdThreadId.isNotEmpty
        ? createdThreadId
        : threadId;
  }

  String _newUuidV7() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final ms = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 6; i++) {
      bytes[i] = (ms >> (8 * (5 - i))) & 0xff;
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x70;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<List<Map<String, dynamic>>> _uploadFiles(List<XFile> files) async {
    final formData = FormData();
    for (final file in files) {
      final mime = file.mimeType;
      final type = mime != null && mime.contains('/')
          ? DioMediaType.parse(mime)
          : null;
      // Pasted images have no file path, so they are sent from their bytes.
      formData.files.add(
        MapEntry(
          'files',
          file.path.isNotEmpty
              ? await MultipartFile.fromFile(
                  file.path,
                  filename: file.name,
                  contentType: type,
                )
              : MultipartFile.fromBytes(
                  await file.readAsBytes(),
                  filename: file.name,
                  contentType: type,
                ),
        ),
      );
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      path: '/files/upload-files',
      data: formData,
    );

    final raw = response.data['data'];
    if (raw is! List || raw.isEmpty) {
      throw ApiFailure(
        message: 'Upload failed. Please try again.',
        path: '/files/upload-files',
        kind: ApiFailureKind.client,
      );
    }
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Deletes a message for everyone. A direct message is not an ordinary
  /// channel on the server: like the web app, it is deleted through the DM
  /// route, not /threads/:id/channels/:id.
  Future<void> deleteMessage({
    required String threadId,
    required String channelId,
  }) async {
    await _apiClient.delete<Map<String, dynamic>>(
      path: '/dms/thread/$threadId/channels/$channelId',
    );
  }

  /// Pins a message for everyone in the conversation, through the route the
  /// web app uses for channels and DMs alike.
  Future<void> pinMessage({
    required String threadId,
    required String channelId,
  }) async {
    await _apiClient.post<Map<String, dynamic>>(
      path: '/channels/pin/$channelId/thread',
      data: {'thread_id': threadId},
    );
  }

  Future<void> editMessage(
    String messageId, {
    required String content,
    String? threadId,
    List<Map<String, dynamic>>? media,
    List<Map<String, dynamic>>? mentions,
  }) async {
    await _apiClient.put<Map<String, dynamic>>(
      path: '/dms/messages/$messageId',
      data: {
        'content': content,
        ...?(threadId != null ? {'thread_id': threadId} : null),
        ...?(media != null ? {'media': media} : null),
        ...?(mentions != null ? {'mentions': mentions} : null),
      },
    );
  }
}
