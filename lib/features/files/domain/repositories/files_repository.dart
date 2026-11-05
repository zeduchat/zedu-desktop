import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class FilesRepository {
  Future<Result<FilesPage>> fetchFiles(FilesQuery query);

  /// Folders in [view], inside [parentId] or at the top level when null.
  Future<Result<FoldersPage>> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  });

  /// Uploads [file] to the signed-in user's files.
  Future<Result<WorkspaceFile>> uploadFile(XFile file);

  /// Creates a folder inside [parentId], or at the top level when null.
  Future<Result<void>> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  });
}
