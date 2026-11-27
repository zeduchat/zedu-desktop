import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class NotificationSettings {
  final DateTime? dndUntil;
  final Set<String> mutedParticipantIds;

  const NotificationSettings({
    this.dndUntil,
    this.mutedParticipantIds = const {},
  });

  bool get isDndActive => dndUntil != null && dndUntil!.isAfter(DateTime.now());
  bool isMuted(String participantId) =>
      mutedParticipantIds.contains(participantId);

  NotificationSettings copyWith({
    DateTime? dndUntil,
    Set<String>? mutedParticipantIds,
  }) {
    return NotificationSettings(
      dndUntil: dndUntil ?? this.dndUntil,
      mutedParticipantIds: mutedParticipantIds ?? this.mutedParticipantIds,
    );
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  Timer? _dndExpiry;

  /// Where this user's mutes are remembered (null while signed out).
  String? _mutedKey;

  /// Where this user's Do Not Disturb end time is remembered.
  String? _dndKey;

  @override
  NotificationSettings build() {
    ref.onDispose(() => _dndExpiry?.cancel());
    // Rebuilt for each signed-in user, so one account never sees another's
    // mutes or Do Not Disturb pause.
    final userId = dmPreferencesUserId(ref);
    final signedIn = userId != null && userId.isNotEmpty;
    _mutedKey = signedIn ? DmPreferencesStore.mutedKey(userId) : null;
    _dndKey = signedIn ? DmPreferencesStore.dndKey(userId) : null;
    final key = _mutedKey;
    if (key != null) _restoreMuted(key);
    final dndKey = _dndKey;
    if (dndKey != null) _restoreDnd(dndKey);
    return const NotificationSettings();
  }

  Future<void> _restoreMuted(String key) async {
    final saved = await ref.read(dmPreferencesStoreProvider).read(key);
    if (!ref.mounted || _mutedKey != key || saved.isEmpty) return;
    // Keep anything muted while the saved list was loading.
    state = state.copyWith(
      mutedParticipantIds: {...saved, ...state.mutedParticipantIds},
    );
  }

  Future<void> _restoreDnd(String key) async {
    final saved = await ref.read(dmPreferencesStoreProvider).readTime(key);
    if (!ref.mounted || _dndKey != key || saved == null) return;
    // A pause chosen while the saved one was loading wins.
    if (state.dndUntil != null) return;
    final remaining = saved.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      // The pause ran out while the app was closed.
      _saveDnd(null);
      return;
    }
    state = state.copyWith(dndUntil: saved);
    _armDndExpiry(remaining);
  }

  void _saveDnd(DateTime? until) {
    final key = _dndKey;
    if (key == null) return;
    unawaited(ref.read(dmPreferencesStoreProvider).writeTime(key, until));
  }

  void _armDndExpiry(Duration remaining) {
    _dndExpiry?.cancel();
    _dndExpiry = Timer(remaining, clearDndMode);
  }

  void _saveMuted() {
    final key = _mutedKey;
    if (key == null) return;
    unawaited(
      ref
          .read(dmPreferencesStoreProvider)
          .write(key, state.mutedParticipantIds),
    );
  }

  /// Pauses notifications; the pause ends by itself when it runs out.
  void setDndMode(Duration duration) {
    final until = DateTime.now().add(duration);
    state = state.copyWith(dndUntil: until);
    _armDndExpiry(duration);
    _saveDnd(until);
  }

  void clearDndMode() {
    _dndExpiry?.cancel();
    _dndExpiry = null;
    state = NotificationSettings(
      dndUntil: null,
      mutedParticipantIds: state.mutedParticipantIds,
    );
    _saveDnd(null);
  }

  void muteParticipant(String participantId) {
    final newMuted = Set<String>.from(state.mutedParticipantIds)
      ..add(participantId);
    state = state.copyWith(mutedParticipantIds: newMuted);
    _saveMuted();
  }

  void unmuteParticipant(String participantId) {
    final newMuted = Set<String>.from(state.mutedParticipantIds)
      ..remove(participantId);
    state = state.copyWith(mutedParticipantIds: newMuted);
    _saveMuted();
  }

  bool isMuted(String participantId) {
    return state.mutedParticipantIds.contains(participantId);
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
      NotificationSettingsNotifier.new,
    );
