import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Whether a message notification plays its sound. On unless the user turns it
/// off in Settings > Notifications; the choice is kept on this device, per
/// signed-in user.
class MessageSoundEnabledNotifier extends Notifier<bool> {
  /// Where this user's choice is remembered (null while signed out).
  String? _key;

  /// Set once the user has changed it, so a slow load cannot undo the change.
  bool _changed = false;

  @override
  bool build() {
    final userId = dmPreferencesUserId(ref);
    _key = userId == null || userId.isEmpty
        ? null
        : DmPreferencesStore.messageSoundKey(userId);
    _changed = false;
    final key = _key;
    if (key != null) _restore(key);
    return true;
  }

  Future<void> _restore(String key) async {
    final saved = await ref.read(dmPreferencesStoreProvider).readFlag(key);
    if (!ref.mounted || _key != key || _changed || saved == null) return;
    state = saved;
  }

  void setEnabled(bool enabled) {
    _changed = true;
    state = enabled;
    final key = _key;
    if (key == null) return;
    unawaited(ref.read(dmPreferencesStoreProvider).writeFlag(key, enabled));
  }
}

final messageSoundEnabledProvider =
    NotifierProvider<MessageSoundEnabledNotifier, bool>(
      MessageSoundEnabledNotifier.new,
    );
