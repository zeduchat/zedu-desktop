import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Remembers when "Clear history" was last used in a conversation, keyed by
/// user and conversation id, so the cleared messages stay hidden after the DM
/// is reopened. Messages are hidden on this device only; nothing is deleted on
/// the server.
class DmHistoryClearStore {
  final SecureStorageService _storage;

  /// Scoped to the signed-in user: both participants share a DM's channel id,
  /// so another account on this device must not inherit the clear.
  final String _keyPrefix;

  DmHistoryClearStore(this._storage, {required String userId})
    : _keyPrefix = 'dm_history_cleared_${userId}_';

  Future<DateTime?> clearedAt(String channelId) async {
    final raw = await _storage.readData('$_keyPrefix$channelId');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markCleared(String channelId, DateTime clearedAt) => _storage
      .writeData('$_keyPrefix$channelId', clearedAt.toUtc().toIso8601String());
}

final dmHistoryClearStoreProvider = Provider<DmHistoryClearStore>((ref) {
  final userId = ref.watch(
    authNotifierProvider.select((state) => state.user?.id ?? ''),
  );
  return DmHistoryClearStore(locator<SecureStorageService>(), userId: userId);
});
