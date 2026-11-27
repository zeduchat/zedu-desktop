import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Ids of the folders being renamed.
class FolderRenamesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Renames [folder] to [name] and reloads the folders when it worked.
  /// Returns what to tell the person when it failed, or null.
  Future<String?> rename(FileFolder folder, String name) async {
    final newName = name.trim();
    if (newName.isEmpty) return 'Enter a folder name.';
    if (newName == folder.name || state.contains(folder.id)) return null;

    state = {...state, folder.id};
    try {
      final result = await ref
          .read(filesRepositoryProvider)
          .renameFolder(folder.id, newName);
      if (!ref.mounted) return null;

      switch (result) {
        case Success():
          ref.invalidate(foldersListProvider);
          return null;
        case Failure(:final error):
          return 'Could not rename ${folder.name}. ${_reason(error)}';
      }
    } finally {
      if (ref.mounted) {
        state = {...state}..remove(folder.id);
      }
    }
  }

  static String _reason(ApiFailure error) => switch (error.kind) {
    ApiFailureKind.unknown || ApiFailureKind.parsing => 'Please try again.',
    _ => error.friendlyMessage,
  };
}
