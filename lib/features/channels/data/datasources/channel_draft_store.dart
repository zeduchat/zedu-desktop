import 'package:zedu/core/core.dart';

/// Client-side persistence for unsent channel drafts, keyed by user, org and
/// channel id.
///
/// Mirrors the direct-message draft store, but only stores the draft text:
/// channel drafts do not need a timestamp yet. Uses the app's existing
/// [SecureStorageService], so a draft never leaks between accounts or orgs.
class ChannelDraftStore {
  final SecureStorageService _storage;

  /// Storage key prefix scoped to the signed-in user and org.
  final String _keyPrefix;

  ChannelDraftStore(
    this._storage, {
    required String userId,
    required String orgId,
  }) : _keyPrefix = 'channel_draft_${userId}_${orgId}_';

  String _keyFor(String channelId) => '$_keyPrefix$channelId';

  /// The saved draft for [channelId], or null when there is none.
  ///
  /// Whitespace-only drafts are treated as empty, the same rule the composer
  /// uses when deciding whether to save.
  Future<String?> getDraft(String channelId) async {
    final raw = await _storage.readData(_keyFor(channelId));
    if (raw == null || raw.trim().isEmpty) return null;
    return raw;
  }

  /// Saves [text] as the draft for [channelId]. Empty text clears the draft.
  Future<void> saveDraft(String channelId, String text) async {
    if (text.trim().isEmpty) {
      await clearDraft(channelId);
      return;
    }
    await _storage.writeData(_keyFor(channelId), text);
  }

  /// Removes the saved draft for [channelId].
  Future<void> clearDraft(String channelId) async {
    await _storage.deleteValue(_keyFor(channelId));
  }
}
