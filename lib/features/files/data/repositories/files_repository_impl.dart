import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class FilesRepositoryImpl implements FilesRepository {
  final FilesRemoteDataSource remoteDataSource;

  FilesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<FilesPage>> fetchFiles(FilesQuery query) async {
    try {
      return Success(await remoteDataSource.fetchFiles(query));
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<FoldersPage>> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  }) async {
    try {
      return Success(
        await remoteDataSource.fetchFolders(
          view: view,
          parentId: parentId,
          page: page,
        ),
      );
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> downloadFile({
    required WorkspaceFile file,
    required String savePath,
    void Function(double? progress)? onProgress,
  }) => _guard(() async {
    await remoteDataSource.downloadFile(
      url: await _linkOf(file),
      savePath: savePath,
      onProgress: onProgress == null
          ? null
          : (received, total) =>
                onProgress(total > 0 ? received / total : null),
    );
  });

  @override
  Future<Result<WorkspaceFile>> uploadFile(XFile file, {String? parentId}) =>
      _guard(() => remoteDataSource.uploadFile(file, parentId: parentId));

  @override
  Future<Result<void>> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  }) => _guard(
    () => remoteDataSource.createFolder(
      name: name,
      orgId: orgId,
      parentId: parentId,
    ),
  );

  @override
  Future<Result<void>> deleteFolder(String id) =>
      _guard(() => remoteDataSource.deleteFolder(id));

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Success(await call());
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteFile(
    String fileId, {
    bool permanent = false,
  }) async {
    try {
      await remoteDataSource.deleteFile(fileId, permanent: permanent);
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> restoreFile(String fileId) =>
      _guard(() => remoteDataSource.restoreFile(fileId));

  @override
  Future<Result<void>> renameFile(String fileId, String name) async {
    try {
      await remoteDataSource.renameFile(fileId, name);
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> moveFile(String fileId, String folderId) async {
    try {
      await remoteDataSource.moveFile(fileId, folderId);
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<FileShareResult>> shareFile({
    required String fileId,
    required List<String> recipientIds,
    required FileSharePermission permission,
    required FileShareAccess access,
    String note = '',
  }) async {
    try {
      return Success(
        await remoteDataSource.shareFile(
          fileId: fileId,
          recipientIds: recipientIds,
          permission: permission,
          access: access,
          note: note,
        ),
      );
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<Uint8List>> fetchFilePreview(
    WorkspaceFile file,
    FilePreviewKind kind,
  ) => _guard(() async {
    // The list's size spares fetching a file that is plainly too large.
    if (file.size > kind.maxBytes) {
      throw const ApiFailure(
        message: 'This file is too large to preview.',
        kind: ApiFailureKind.client,
      );
    }
    return remoteDataSource.fetchFileBytes(
      url: await _linkOf(file),
      maxBytes: kind.maxBytes,
    );
  });

  /// [file]'s storage link: from the list, else from the server.
  Future<String> _linkOf(WorkspaceFile file) async {
    final link = file.link.isNotEmpty
        ? file.link
        : await remoteDataSource.fetchFileLink(file.id);
    if (link.isEmpty) {
      throw const ApiFailure(
        message: 'This file has no download link.',
        kind: ApiFailureKind.client,
      );
    }
    return link;
  }

  @override
  Future<Result<WorkspaceFile>> fetchFileDetails(String fileId) =>
      _guard(() => remoteDataSource.fetchFileDetails(fileId));

  @override
  Future<Result<WorkspaceFileInfo>> fetchFileInfo(String fileId) =>
      _guard(() => remoteDataSource.fetchFileInfo(fileId));

  @override
  Future<Result<Set<String>>> fetchPinnedFileIds() =>
      _guard(remoteDataSource.fetchPinnedFileIds);

  @override
  Future<Result<void>> pinFile(String fileId) =>
      _guard(() => remoteDataSource.pinFile(fileId));

  @override
  Future<Result<void>> unpinFile(String fileId) =>
      _guard(() => remoteDataSource.unpinFile(fileId));
}
