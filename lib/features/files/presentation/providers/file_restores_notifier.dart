import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Ids of the files being restored from Deleted files.
class FileRestoresNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Restores [file] from Deleted files and reloads the list, which then no
  /// longer shows it. Returns what to tell the person when it failed, or null.
  Future<String?> restore(WorkspaceFile file) async {
    if (state.contains(file.id)) return null;
    state = {...state, file.id};
    final result = await ref.read(filesRepositoryProvider).restoreFile(file.id);
    if (!ref.mounted) return null;
    state = {...state}..remove(file.id);

    switch (result) {
      case Success():
        ref.invalidate(filesListProvider);
        return null;
      case Failure(:final error):
        return 'Could not restore ${file.name}. ${_reason(error)}';
    }
  }

  static String _reason(ApiFailure error) => switch (error.kind) {
    ApiFailureKind.unknown || ApiFailureKind.parsing => 'Please try again.',
    _ => error.friendlyMessage,
  };
}
