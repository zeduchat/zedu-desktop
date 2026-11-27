import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// One page of the notifications feed.
typedef NotificationPage = ({List<AppNotification> items, bool hasMore});

/// Loads the notifications feed zedu-fe's Notifications page uses and keeps
/// which ones were read, per user and organisation, like zedu-fe's
/// notification-store (the feed's own `is_read` plus a local set of ids).
class NotificationCenterRepository {
  NotificationCenterRepository({
    required ApiBaseService api,
    required SecureStorageService storage,
  }) : _api = api,
       _storage = storage;

  final ApiBaseService _api;
  final SecureStorageService _storage;

  static const pageSize = 20;
  static const _maxStoredIds = 500;

  Future<NotificationPage> load(String orgId, {int page = 1}) async {
    final response = await _api.get<Map<String, dynamic>>(
      path: '/organisations/$orgId/users/onesignal',
      queryParameters: {'page': page, 'limit': pageSize},
    );
    final data = response.data['data'];
    final rawItems = data is Map ? data['notifications'] : null;
    final items = <AppNotification>[
      if (rawItems is List)
        for (final raw in rawItems.whereType<Map<dynamic, dynamic>>())
          AppNotification.fromJson(Map<String, dynamic>.from(raw)),
    ].where((item) => item.id.isNotEmpty).toList();

    final pagination = data is Map ? data['pagination'] : null;
    bool hasMore;
    if (items.isEmpty) {
      hasMore = false;
    } else if (pagination is Map) {
      final current = int.tryParse('${pagination['current_page']}');
      final total = int.tryParse('${pagination['total_pages_count']}');
      hasMore = current != null && total != null
          ? current < total
          : items.length >= pageSize;
    } else {
      hasMore = items.length >= pageSize;
    }
    return (items: items, hasMore: hasMore);
  }

  /// Marks [notificationId] read on the server for the signed-in user, so
  /// Zedu web (which treats `status: read` as read) clears it too.
  Future<void> markRead(String notificationId) async {
    await _api.put<Map<String, dynamic>>(
      path: '/users/onesignal-notifications/$notificationId/read',
    );
  }

  static String _readKey(String userId, String orgId) =>
      'zedu_read_notifications_${userId}_$orgId';
  static String _seenAtKey(String userId, String orgId) =>
      'zedu_notifications_seen_at_${userId}_$orgId';

  Future<Set<String>> readIds(String userId, String orgId) async {
    final raw = await _storage.readData(_readKey(userId, orgId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.map((id) => '$id').toSet() : {};
    } on FormatException {
      return {};
    }
  }

  Future<void> saveReadIds(String userId, String orgId, Set<String> ids) {
    // Newest last, so the oldest are dropped when the cap is reached.
    final list = ids.toList();
    final kept = list.length > _maxStoredIds
        ? list.sublist(list.length - _maxStoredIds)
        : list;
    return _storage.writeData(_readKey(userId, orgId), jsonEncode(kept));
  }

  /// When notifications were first loaded on this device: older ones count
  /// as read, so the first visit isn't a wall of unread history (zedu-fe's
  /// `seenAt`).
  Future<DateTime?> seenAt(String userId, String orgId) async {
    final raw = await _storage.readData(_seenAtKey(userId, orgId));
    final millis = int.tryParse(raw ?? '');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<DateTime> markSeenNow(String userId, String orgId) async {
    final now = DateTime.now();
    await _storage.writeData(
      _seenAtKey(userId, orgId),
      '${now.millisecondsSinceEpoch}',
    );
    return now;
  }
}

final notificationCenterRepositoryProvider =
    Provider<NotificationCenterRepository>(
      (ref) => NotificationCenterRepository(
        api: locator<ApiBaseService>(),
        storage: locator<SecureStorageService>(),
      ),
    );
