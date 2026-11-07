import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Uses the shared bookmark routes used by zedu-fe.
class LaterRepository {
  LaterRepository(this.api);
  final ApiBaseService api;
  Future<List<SavedMessage>> load(String orgId) async {
    final items = <String, SavedMessage>{};
    for (var page = 1; page <= 100; page++) {
      final response = await api.get<Map<String, dynamic>>(
        path: '/organisations/$orgId/saved/message',
        queryParameters: {'page': page, 'limit': 100},
      );
      final data = response.data['data'];
      if (data is! List) {
        throw const ApiFailure(message: 'Could not read saved messages.');
      }
      var added = 0;
      for (final raw in data.whereType<Map<dynamic, dynamic>>()) {
        final item = SavedMessage.fromJson(Map<String, dynamic>.from(raw));
        if (item.id.isEmpty) continue;
        if (!items.containsKey(item.id)) added++;
        items[item.id] = item;
      }
      final pagination = response.data['pagination'];
      final total = pagination is Map
          ? int.tryParse('${pagination['total_pages']}')
          : null;
      if (total == null || page >= total || data.isEmpty) {
        return items.values.toList();
      }
      if (added == 0) break;
    }
    throw const ApiFailure(
      message: 'Could not load all saved messages. Please retry.',
    );
  }

  Future<void> save(String orgId, String channelId, String threadId) async {
    await api.post<Map<String, dynamic>>(
      path: '/organisations/$orgId/thread/save',
      data: {
        'channels_id': channelId,
        'thread_id': threadId,
        'type': 'message',
      },
    );
  }

  Future<void> remove(String orgId, String id) async {
    await api.delete<Map<String, dynamic>>(
      path: '/organisations/$orgId/saved/message/$id',
    );
  }

  /// Locate older messages using the existing paginated conversation endpoints.
  Future<Map<String, dynamic>?> locate(
    SavedMessage item, {
    required bool isDm,
  }) async {
    final seen = <String>{};
    for (var page = 1; page <= 100; page++) {
      final response = await api.get<Map<String, dynamic>>(
        path: isDm
            ? '/channels/${item.channelId}/messages'
            : '/threads/channels/${item.channelId}',
        queryParameters: {'page': page, 'limit': 50},
      );
      final data = response.data['messages'] ?? response.data['data'];
      final list = data is Map ? data['messages'] ?? data['data'] : data;
      if (list is! List) {
        throw const ApiFailure(
          message: 'Could not read the original conversation.',
        );
      }
      if (list.isEmpty) return null;
      var added = 0;
      for (final raw in list.whereType<Map<dynamic, dynamic>>()) {
        final message = Map<String, dynamic>.from(raw);
        final id = (message['thread_id'] ?? message['id'] ?? '').toString();
        if (id == item.id || message['id']?.toString() == item.id) {
          return message;
        }
        if (seen.add(id)) added++;
      }
      if (added == 0) break;
      final pagination = response.data['pagination'];
      final total = pagination is Map
          ? int.tryParse('${pagination['total_pages']}')
          : null;
      if (total != null && page >= total) return null;
    }
    throw const ApiFailure(
      message:
          'The message could not be located within the history search limit.',
    );
  }
}

final laterRepositoryProvider = Provider(
  (ref) => LaterRepository(locator<ApiBaseService>()),
);
final savedMessagesProvider = FutureProvider<List<SavedMessage>>((ref) {
  final orgId = ref.watch(
    workspaceProvider.select((s) => s.selectedWorkspace?.id),
  );
  if (orgId == null) return Future.value([]);
  final userId = ref.watch(authNotifierProvider.select((s) => s.user?.id));
  return userId == null
      ? Future.value([])
      : ref.watch(laterRepositoryProvider).load(orgId);
}, retry: (_, _) => null);
