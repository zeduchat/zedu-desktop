import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final savedRepositoryProvider = Provider<SavedRepository>((ref) {
  return SavedRepository(locator<ApiBaseService>());
});

/// The saved-message endpoints the web app already uses, so the saved list is
/// shared between desktop and web.
///
/// Reminders are not here: they are a separate resource on the server, in
/// [ReminderRepository].
class SavedRepository {
  SavedRepository(this._apiClient);

  final ApiBaseService _apiClient;

  Future<List<SavedMessage>> list({required String orgId}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      path: '/organisations/$orgId/saved/message',
    );

    final raw = response.data['data'];
    return (raw is List ? raw : const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SavedMessage.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  /// Saves a message. A whole thread and a reply inside one take different
  /// endpoints, and the reply also sends its own id.
  Future<void> save({
    required String orgId,
    required SavedTarget target,
  }) async {
    final messageId = target.messageId;
    if (messageId == null) {
      await _apiClient.post<Map<String, dynamic>>(
        path: '/organisations/$orgId/thread/save',
        data: {'channels_id': target.channelId, 'thread_id': target.threadId},
      );
      return;
    }

    await _apiClient.post<Map<String, dynamic>>(
      path: '/organisations/$orgId/message/save',
      data: {
        'channels_id': target.channelId,
        'thread_id': target.threadId,
        'message_id': messageId,
      },
    );
  }

  /// Removes a saved item by **the saved item's own id**. The thread id
  /// answers 404 here, which is why the list has to be loaded before a
  /// message can be unsaved.
  Future<void> remove({
    required String orgId,
    required String savedMessageId,
  }) async {
    await _apiClient.delete<Map<String, dynamic>>(
      path: '/organisations/$orgId/saved/message/$savedMessageId',
    );
  }
}
