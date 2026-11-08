import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final filesRemoteDataSourceProvider = Provider<FilesRemoteDataSource>(
  (ref) => FilesRemoteDataSourceImpl(
    apiBaseService: locator<ApiBaseService>(),
    config: locator<AppConfig>(),
  ),
);

final filesRepositoryProvider = Provider<FilesRepository>(
  (ref) => FilesRepositoryImpl(
    remoteDataSource: ref.watch(filesRemoteDataSourceProvider),
  ),
);

final filesProvider = NotifierProvider<FilesNotifier, FilesState>(
  FilesNotifier.new,
);

final filesListProvider = AsyncNotifierProvider<FilesListNotifier, FilesPage>(
  FilesListNotifier.new,
);

final foldersListProvider =
    AsyncNotifierProvider<FoldersListNotifier, FoldersPage>(
      FoldersListNotifier.new,
    );

final filesActionsProvider =
    NotifierProvider<FilesActionsNotifier, FilesActionsState>(
      FilesActionsNotifier.new,
    );

final saveLocationPickerProvider = Provider<SaveLocationPicker>(
  (ref) =>
      (fileName) => FilePicker.saveFile(
        dialogTitle: 'Save file',
        fileName: fileName,
        lockParentWindow: true,
      ),
);

final fileDownloadsProvider =
    NotifierProvider<FileDownloadsNotifier, Map<String, double?>>(
      FileDownloadsNotifier.new,
    );

final fileDeletionsProvider =
    NotifierProvider<FileDeletionsNotifier, Set<String>>(
      FileDeletionsNotifier.new,
    );

final fileRestoresProvider =
    NotifierProvider<FileRestoresNotifier, Set<String>>(
      FileRestoresNotifier.new,
    );

final fileRenamesProvider = NotifierProvider<FileRenamesNotifier, Set<String>>(
  FileRenamesNotifier.new,
);

final fileMovesProvider = NotifierProvider<FileMovesNotifier, Set<String>>(
  FileMovesNotifier.new,
);

/// The folders a file can be moved into, one level at a time: the folders
/// inside the folder with id `parentId`, or the top-level folders when it is
/// null, across every page.
final moveTargetFoldersProvider = FutureProvider.autoDispose
    .family<List<FileFolder>, String?>((ref, parentId) async {
      final repository = ref.watch(filesRepositoryProvider);
      final folders = <FileFolder>[];
      for (var page = 1; ; page++) {
        final result = await repository.fetchFolders(
          view: FilesScope.all,
          parentId: parentId,
          page: page,
        );
        final value = switch (result) {
          Success(:final value) => value,
          Failure(:final error) => throw error,
        };
        folders.addAll(value.folders);
        if (value.folders.isEmpty || page >= value.totalPages) return folders;
      }
    });

final fileSharesProvider = NotifierProvider<FileSharesNotifier, Set<String>>(
  FileSharesNotifier.new,
);

final pinnedFilesProvider =
    AsyncNotifierProvider<PinnedFilesNotifier, Set<String>>(
      PinnedFilesNotifier.new,
    );

/// A file's current details from the server, for its Info panel.
final fileDetailsProvider = FutureProvider.autoDispose
    .family<WorkspaceFile, String>((ref, fileId) async {
      final result = await ref
          .watch(filesRepositoryProvider)
          .fetchFileDetails(fileId);
      return switch (result) {
        Success(:final value) => value,
        Failure(:final error) => throw error,
      };
    });

/// What the server knows about a file beyond its list entry, such as the
/// channels it was shared in. The list endpoint leaves that out.
final fileInfoProvider = FutureProvider.autoDispose
    .family<WorkspaceFileInfo, String>((ref, fileId) async {
      final result = await ref
          .watch(filesRepositoryProvider)
          .fetchFileInfo(fileId);
      return switch (result) {
        Success(:final value) => value,
        Failure(:final error) => throw error,
      };
    });
