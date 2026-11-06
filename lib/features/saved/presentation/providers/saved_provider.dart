import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The saved list, and the pending reminders that belong to its rows.
class SavedState {
  const SavedState({
    this.items = const [],
    this.reminders = const {},
    this.loading = false,
    this.error,
    this.loaded = false,
  });

  final List<SavedMessage> items;

  /// Pending reminders by `SavedTarget.key`, so a row can show its own.
  final Map<String, MessageReminder> reminders;

  final bool loading;
  final Object? error;

  /// Whether the list has been fetched at least once, so the empty state
  /// cannot be shown before the first load.
  final bool loaded;

  MessageReminder? reminderFor(SavedTarget target) => reminders[target.key];

  SavedState copyWith({
    List<SavedMessage>? items,
    Map<String, MessageReminder>? reminders,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? loaded,
  }) => SavedState(
    items: items ?? this.items,
    reminders: reminders ?? this.reminders,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    loaded: loaded ?? this.loaded,
  );
}

/// The saved messages and their reminders.
///
/// This deliberately does **not** fetch in [build], and does not watch the
/// selected workspace. Every message menu asks whether its message is saved,
/// and making that question reach the workspace provider would give every
/// message bubble a hidden dependency on organisation loading and a network
/// call at startup. The list is fetched when something asks for it: the Home
/// sidebar on mount and on a workspace switch, and after saving, removing or
/// reminding.
class SavedNotifier extends Notifier<SavedState> {
  @override
  SavedState build() => const SavedState();

  String get _orgId => ref.read(currentOrgIdProvider);

  /// The client's offset from UTC in minutes east, which is what the reminder
  /// endpoint expects.
  int get _tzOffsetMinutes => DateTime.now().timeZoneOffset.inMinutes;

  /// Rows whose reminder time has already passed come first, then the most
  /// recently saved.
  static List<SavedMessage> sortForDisplay(
    List<SavedMessage> items,
    Map<String, MessageReminder> reminders, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    bool due(SavedMessage item) =>
        reminders[item.target.key]?.isDue(clock) ?? false;

    final sorted = [...items];
    sorted.sort((a, b) {
      final dueA = due(a);
      final dueB = due(b);
      if (dueA != dueB) return dueA ? -1 : 1;
      return b.savedAt.compareTo(a.savedAt);
    });
    return sorted;
  }

  Future<void> refresh() async {
    final orgId = _orgId;
    if (orgId.isEmpty) {
      state = const SavedState(loaded: true);
      return;
    }

    state = state.copyWith(loading: true, clearError: true);
    try {
      // Two independent lists: saved messages, and the reminders the web
      // client also reads. Fetched together so a row and its reminder cannot
      // disagree.
      final results = await Future.wait([
        ref.read(savedRepositoryProvider).list(orgId: orgId),
        ref.read(reminderRepositoryProvider).list(orgId: orgId),
      ]);

      final items = results[0] as List<SavedMessage>;
      final reminders = {
        for (final reminder in results[1] as List<MessageReminder>)
          reminder.key: reminder,
      };

      state = SavedState(
        items: sortForDisplay(items, reminders),
        reminders: reminders,
        loaded: true,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error, loaded: true);
    }
  }

  /// Saves the message, then reloads so the new row carries the server's own
  /// id, which removing it later needs.
  Future<void> save(SavedTarget target) async {
    final orgId = _orgId;
    if (orgId.isEmpty) return;
    await ref.read(savedRepositoryProvider).save(orgId: orgId, target: target);
    await refresh();
  }

  Future<void> removeById(String savedMessageId) async {
    final orgId = _orgId;
    if (orgId.isEmpty) return;
    await ref
        .read(savedRepositoryProvider)
        .remove(orgId: orgId, savedMessageId: savedMessageId);
    await refresh();
  }

  /// Removes whatever saved item corresponds to [target].
  ///
  /// Removing needs the saved item's own id, which only the list carries, so
  /// the list is fetched first when it has not been.
  Future<void> removeTarget(SavedTarget target) async {
    if (!state.loaded) await refresh();
    final saved = savedFor(target);
    if (saved == null) return;
    await removeById(saved.id);
  }

  /// Sets a reminder on a message.
  ///
  /// The reminder itself is independent of saving on the server, but the
  /// message is saved first when it is not already: that is what this
  /// ticket asks for, and it is what gives the reminder a row to appear on in
  /// the Saved list.
  ///
  /// An existing pending reminder on the same message is removed first, so
  /// choosing a new time replaces the old one rather than firing twice.
  ///
  /// Nothing is swallowed. If any call fails the error reaches the caller,
  /// which reports it, rather than leaving a reminder the user believes is
  /// set.
  Future<void> setReminder({
    required SavedTarget target,
    required ReminderPreset preset,
  }) async {
    final orgId = _orgId;
    if (orgId.isEmpty) return;

    if (!state.loaded) await refresh();

    if (savedFor(target) == null) {
      await ref
          .read(savedRepositoryProvider)
          .save(orgId: orgId, target: target);
    }

    final reminders = ref.read(reminderRepositoryProvider);
    final existing = state.reminderFor(target);
    if (existing != null) {
      await reminders.delete(orgId: orgId, reminderId: existing.id);
    }

    await reminders.create(
      orgId: orgId,
      target: target,
      preset: preset,
      tzOffsetMinutes: _tzOffsetMinutes,
    );
    await refresh();
  }

  /// Cancels the pending reminder on a message, leaving it saved.
  Future<void> clearReminder(SavedTarget target) async {
    final orgId = _orgId;
    final existing = state.reminderFor(target);
    if (orgId.isEmpty || existing == null) return;
    await ref
        .read(reminderRepositoryProvider)
        .delete(orgId: orgId, reminderId: existing.id);
    await refresh();
  }

  /// The saved item for a message, or null when it is not saved.
  SavedMessage? savedFor(SavedTarget target) {
    for (final item in state.items) {
      if (item.target.key == target.key) return item;
    }
    return null;
  }
}

final savedProvider = NotifierProvider<SavedNotifier, SavedState>(
  SavedNotifier.new,
);

/// Which messages are saved, for the message menu's label.
///
/// Reading this never starts a fetch, so a message bubble costs nothing until
/// the user opens Saved or saves something.
final savedKeysProvider = Provider<Set<String>>((ref) {
  final items = ref.watch(savedProvider).items;
  return {for (final item in items) item.target.key};
});
