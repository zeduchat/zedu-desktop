import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Remembers on this computer which DMs a person pinned, which people they
/// muted and when their Do Not Disturb pause ends, so all survive an app
/// restart. Kept per signed-in user, so another
/// account on the same machine starts with its own.
///
/// The backend has no field for any of them yet, hence local storage.
class DmPreferencesStore {
  const DmPreferencesStore();

  static const _tag = 'DmPreferencesStore';

  static String pinnedKey(String userId) => 'dm_pinned_channels_$userId';
  static String mutedKey(String userId) => 'dm_muted_participants_$userId';
  static String dndKey(String userId) => 'dm_dnd_until_$userId';

  Future<Set<String>> read(String key) async {
    if (!locator.isRegistered<SecureStorageService>()) return {};
    try {
      final raw = await locator<SecureStorageService>().readData(key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.whereType<String>().toSet() : {};
    } catch (error) {
      AppLogger.w('Could not read $key - $error', tag: _tag);
      return {};
    }
  }

  Future<void> write(String key, Set<String> ids) async {
    if (!locator.isRegistered<SecureStorageService>()) return;
    try {
      await locator<SecureStorageService>().writeData(
        key,
        jsonEncode(ids.toList()..sort()),
      );
    } catch (error) {
      AppLogger.w('Could not save $key - $error', tag: _tag);
    }
  }

  /// The saved end of a Do Not Disturb pause, or null when none is saved.
  Future<DateTime?> readTime(String key) async {
    if (!locator.isRegistered<SecureStorageService>()) return null;
    try {
      final raw = await locator<SecureStorageService>().readData(key);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    } catch (error) {
      AppLogger.w('Could not read $key - $error', tag: _tag);
      return null;
    }
  }

  /// Saves [time] under [key], or forgets it when [time] is null.
  Future<void> writeTime(String key, DateTime? time) async {
    if (!locator.isRegistered<SecureStorageService>()) return;
    try {
      final storage = locator<SecureStorageService>();
      if (time == null) {
        await storage.deleteValue(key);
      } else {
        await storage.writeData(key, time.toUtc().toIso8601String());
      }
    } catch (error) {
      AppLogger.w('Could not save $key - $error', tag: _tag);
    }
  }
}

final dmPreferencesStoreProvider = Provider<DmPreferencesStore>(
  (ref) => const DmPreferencesStore(),
);

/// The signed-in user's id, or null when signed out (or when auth isn't
/// available, as in some widget tests).
String? dmPreferencesUserId(Ref ref) {
  try {
    return ref.watch(authNotifierProvider.select((s) => s.user?.id));
  } catch (_) {
    return null;
  }
}
