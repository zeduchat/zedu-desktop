import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Client-side persistence for unsent message drafts, keyed by user, org and
/// conversation id.
///
/// Mirrors the mobile app's draft keys (`user:org:scope:roomId`) closely enough
/// to be familiar, but is desktop-local storage only. Uses the app's existing
/// FlutterSecureStorage via SecureStorageService, following the same JSON
/// encoding pattern as ChatStorageService.
class DraftEntry {
  final String text;
  final int updatedAt;

  const DraftEntry({required this.text, required this.updatedAt});

  Map<String, dynamic> toJson() => {'text': text, 'updatedAt': updatedAt};

  factory DraftEntry.fromJson(Map<String, dynamic> json) => DraftEntry(
    text: json['text'] as String? ?? '',
    updatedAt: json['updatedAt'] as int? ?? 0,
  );
}

class DmDraftStore {
  final SecureStorageService _storage;

  /// Storage key prefix scoped to the signed-in user and org, so a DM's draft
  /// (same channel id for both participants) never leaks to another account.
  final String _keyPrefix;

  /// In-memory cache keyed by channel id so list tiles rebuild instantly.
  /// A null value means "known empty" (loaded from disk, nothing there, or
  /// cleared by the composer).
  final Map<String, DraftEntry?> _cache = {};

  /// Channel ids already read from storage at least once.
  final Set<String> _loaded = {};

  DmDraftStore(this._storage, {required String userId, required String orgId})
    : _keyPrefix = 'dm_draft_${userId}_${orgId}_';

  /// Cached entry without triggering any IO. Null means "no draft" — either
  /// known-absent or not-yet-loaded (check [hasLoaded]).
  DraftEntry? peek(String channelId) => _cache[channelId];

  /// True when this conversation's storage has been read at least once.
  bool hasLoaded(String channelId) => _loaded.contains(channelId);

  Future<DraftEntry?> load(String channelId) async {
    _loaded.add(channelId);
    if (_cache.containsKey(channelId)) return _cache[channelId];

    final raw = await _storage.readData('$_keyPrefix$channelId');
    DraftEntry? entry;
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final parsed = DraftEntry.fromJson(decoded);
          // Whitespace-only drafts are not drafts (same rule as mobile).
          if (parsed.text.trim().isNotEmpty) entry = parsed;
        }
      } catch (_) {
        entry = null;
      }
    }
    _cache[channelId] = entry;
    return entry;
  }

  Future<void> save(String channelId, String text, {int? updatedAt}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await clear(channelId);
      return;
    }

    final entry = DraftEntry(
      text: text,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    _cache[channelId] = entry;
    try {
      await _storage.writeData(
        '$_keyPrefix$channelId',
        jsonEncode(entry.toJson()),
      );
    } catch (_) {
      // Storage failure should not break composing; cache stays valid.
    }
  }

  Future<void> clear(String channelId) async {
    _cache[channelId] = null;
    try {
      await _storage.deleteValue('$_keyPrefix$channelId');
    } catch (_) {}
  }
}

/// Immutable snapshot handed to widgets. It exposes the cache read helpers and
/// is replaced after every write so `ref.watch` rebuilds the draft indicators.
class DmDraftState {
  const DmDraftState(this.store);

  final DmDraftStore store;

  /// Cached entry without triggering any IO. Null means "no draft" — either
  /// known-absent or not-yet-loaded (check [hasLoaded]).
  DraftEntry? peek(String channelId) => store.peek(channelId);

  /// True when this conversation's storage has been read at least once.
  bool hasLoaded(String channelId) => store.hasLoaded(channelId);
}

class DmDraftNotifier extends Notifier<DmDraftState> {
  /// [store] is only passed by tests, which inject a fake-backed store.
  DmDraftNotifier([DmDraftStore? store]) : _injectedStore = store;

  final DmDraftStore? _injectedStore;

  late DmDraftStore _store;

  @override
  DmDraftState build() {
    final injected = _injectedStore;
    if (injected != null) {
      _store = injected;
      return DmDraftState(_store);
    }
    // Rebuilding on a user or org change also drops the previous in-memory
    // cache, because a fresh store is created for the new scope.
    final userId = ref.watch(
      authNotifierProvider.select((state) => state.user?.id ?? ''),
    );
    final orgId = ref.watch(currentOrgIdProvider);
    _store = DmDraftStore(
      locator<SecureStorageService>(),
      userId: userId,
      orgId: orgId,
    );
    return DmDraftState(_store);
  }

  Future<DraftEntry?> load(String channelId) async {
    final entry = await _store.load(channelId);
    _publish();
    return entry;
  }

  Future<void> save(String channelId, String text, {int? updatedAt}) async {
    await _store.save(channelId, text, updatedAt: updatedAt);
    _publish();
  }

  Future<void> clear(String channelId) async {
    await _store.clear(channelId);
    _publish();
  }

  void _publish() => state = DmDraftState(_store);
}

final dmDraftStoreProvider = NotifierProvider<DmDraftNotifier, DmDraftState>(
  DmDraftNotifier.new,
);
