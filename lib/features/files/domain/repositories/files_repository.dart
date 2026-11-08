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
  Future<Result<WorkspaceFile>> uploadFile(XFile file, {String? parentId});

  /// Creates a folder inside [parentId], or at the top level when null.
  Future<Result<void>> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  });

  /// Saves [file] to [savePath]. Uses the file's own link, or asks the server
  /// for it when the list did not include one. [onProgress] gets the share
  /// downloaded, from 0 to 1, or null while the size is unknown.
  Future<Result<void>> downloadFile({
    required WorkspaceFile file,
    required String savePath,
    void Function(double? progress)? onProgress,
  });

  /// Deletes [fileId]: moves it to Deleted files, or removes it for good when
  /// [permanent].
  Future<Result<void>> deleteFile(String fileId, {bool permanent = false});

  /// Restores [fileId] from Deleted files.
  Future<Result<void>> restoreFile(String fileId);

  /// Renames [fileId] to [name].
  Future<Result<void>> renameFile(String fileId, String name);

  /// Moves [fileId] into folder [folderId].
  Future<Result<void>> moveFile(String fileId, String folderId);

  /// Shares [fileId] with [recipientIds] by direct message.
  Future<Result<FileShareResult>> shareFile({
    required String fileId,
    required List<String> recipientIds,
    required FileSharePermission permission,
    required FileShareAccess access,
    String note = '',
  });

  /// [file]'s contents for a preview of [kind], or a client failure when it
  /// is too large for that.
  Future<Result<Uint8List>> fetchFilePreview(
    WorkspaceFile file,
    FilePreviewKind kind,
  );

  /// [fileId]'s current details, including its access type.
  Future<Result<WorkspaceFile>> fetchFileDetails(String fileId);

  /// [fileId]'s info, including the channels it was shared in. The files list
  /// does not carry that, so it comes from its own route.
  Future<Result<WorkspaceFileInfo>> fetchFileInfo(String fileId);

  /// Ids of the files the user pinned. Pins belong to the user, not the file.
  Future<Result<Set<String>>> fetchPinnedFileIds();

  Future<Result<void>> pinFile(String fileId);

  Future<Result<void>> unpinFile(String fileId);

  /// Deletes the folder [id] and its contents.
  Future<Result<void>> deleteFolder(String id);
}
