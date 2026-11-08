import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class FilesRemoteDataSource {
  Future<FilesPage> fetchFiles(FilesQuery query);

  Future<FoldersPage> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  });

  Future<WorkspaceFile> uploadFile(XFile file, {String? parentId});

  Future<void> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  });

  /// The download link of file [fileId], or empty when it has none.
  Future<String> fetchFileLink(String fileId);

  /// Downloads [url] to [savePath]. [onProgress] gets the bytes received and
  /// the total, which is -1 when the server does not say.
  Future<void> downloadFile({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
  });

  /// Deletes file [fileId]: moves it to Deleted files, or removes it for good
  /// when [permanent].
  Future<void> deleteFile(String fileId, {bool permanent = false});

  /// Restores file [fileId] from Deleted files.
  Future<void> restoreFile(String fileId);

  /// Renames file [fileId] to [name].
  Future<void> renameFile(String fileId, String name);

  /// Moves file [fileId] into folder [folderId].
  Future<void> moveFile(String fileId, String folderId);

  /// Shares file [fileId] with [recipientIds], sending it to each of them by
  /// direct message, as the web app does.
  Future<FileShareResult> shareFile({
    required String fileId,
    required List<String> recipientIds,
    required FileSharePermission permission,
    required FileShareAccess access,
    String note = '',
  });

  /// The contents at [url], for a preview. Fails with a client error when
  /// they are larger than [maxBytes].
  Future<Uint8List> fetchFileBytes({
    required String url,
    required int maxBytes,
  });

  /// File [fileId] as `GET /files/file/{id}` reports it now.
  Future<WorkspaceFile> fetchFileDetails(String fileId);

  /// What `GET /files/file/{id}/info` says about the file, including the
  /// channels it was shared in.
  Future<WorkspaceFileInfo> fetchFileInfo(String fileId);

  /// Ids of the files the user pinned, from `GET /files/favorites`.
  Future<Set<String>> fetchPinnedFileIds();

  Future<void> pinFile(String fileId);

  Future<void> unpinFile(String fileId);

  Future<void> deleteFolder(String id);
}

/// Reads `current_page` and `total_pages_count` (or `total_pages`).
(int, int) _pagination(Object? pagination, int requestedPage) {
  int value(List<String> keys, int fallback) {
    if (pagination is! Map) return fallback;
    for (final key in keys) {
      final parsed = num.tryParse(pagination[key]?.toString() ?? '');
      if (parsed != null) return parsed.toInt();
    }
    return fallback;
  }

  final current = value(['current_page'], requestedPage);
  final total = value(['total_pages_count', 'total_pages'], 1);
  return (current < 1 ? 1 : current, total < 1 ? 1 : total);
}

/// Talks to the same `/files` endpoints as the web app. The server picks
/// the organisation from the signed-in session.
class FilesRemoteDataSourceImpl implements FilesRemoteDataSource {
  final ApiBaseService apiBaseService;
  final AppConfig config;

  /// Fetches file contents from their storage links. It is a plain client,
  /// so the session token is never sent to the storage host.
  final Dio downloadClient;

  FilesRemoteDataSourceImpl({
    required this.apiBaseService,
    required this.config,
    Dio? downloadClient,
  }) : downloadClient = downloadClient ?? Dio();

  /// The mock build has no files to serve, and staging rejects its token, so
  /// changes fail here instead of sending a request that signs the user out.
  static const _mockBuildFailure = ApiFailure(
    message: 'Not available in the mock build.',
    kind: ApiFailureKind.client,
  );

  /// Folders per page, as the web app asks for.
  static const pageSize = 10;

  @override
  Future<FilesPage> fetchFiles(FilesQuery query) async {
    if (config.usesMockData) return const FilesPage(files: []);
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/files',
      queryParameters: query.toQueryParameters(),
    );
    final data = response.data['data'];
    final body = data is Map ? data : const <String, dynamic>{};
    final rawFiles = body['files'];
    final files = (rawFiles is List ? rawFiles : const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => WorkspaceFile.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final (currentPage, totalPages) = _pagination(
      body['pagination'],
      query.page,
    );
    return FilesPage(
      files: files,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  @override
  Future<FoldersPage> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  }) async {
    if (config.usesMockData) return const FoldersPage(folders: []);
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/files/folders',
      queryParameters: {
        'mode': view.apiMode,
        'page': page,
        'limit': pageSize,
        if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
      },
    );
    final data = response.data['data'];
    final body = data is Map ? data : const <String, dynamic>{};
    final rawFolders = body['folders'];
    final folders = (rawFolders is List ? rawFolders : const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => FileFolder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final (currentPage, totalPages) = _pagination(body['pagination'], page);
    return FoldersPage(
      folders: folders,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  /// Sends one file as the `files` part, as the web app does. The server
  /// files it at the top level of the user's files.
  @override
  Future<WorkspaceFile> uploadFile(XFile file, {String? parentId}) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final mime = file.mimeType;
    final type = mime != null && mime.contains('/')
        ? DioMediaType.parse(mime)
        : null;
    final formData = FormData()
      ..files.add(
        MapEntry(
          'files',
          file.path.isNotEmpty
              ? await MultipartFile.fromFile(
                  file.path,
                  filename: file.name,
                  contentType: type,
                )
              : MultipartFile.fromBytes(
                  await file.readAsBytes(),
                  filename: file.name,
                  contentType: type,
                ),
        ),
      );

    if (parentId != null && parentId.isNotEmpty) {
      formData.fields.add(MapEntry('folder_id', parentId));
    }

    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/files/upload-files',
      data: formData,
    );
    final raw = response.data['data'];
    if (raw is! List || raw.isEmpty || raw.first is! Map) {
      throw const ApiFailure(
        message: 'Upload failed. Please try again.',
        path: '/files/upload-files',
        kind: ApiFailureKind.client,
      );
    }
    return WorkspaceFile.fromJson(
      Map<String, dynamic>.from(raw.first as Map<dynamic, dynamic>),
    );
  }

  @override
  Future<void> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/files/folders',
      data: {
        'name': name,
        'parent_id': parentId != null && parentId.isNotEmpty ? parentId : null,
        'organisation_id': orgId,
      },
    );
  }

  @override
  Future<String> fetchFileLink(String fileId) async {
    if (config.usesMockData) return '';
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/files/file/$fileId',
    );
    final data = response.data['data'];
    return data is Map ? data['file_link']?.toString().trim() ?? '' : '';
  }

  @override
  Future<void> downloadFile({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    try {
      await downloadClient.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
      );
    } on DioException catch (error) {
      throw ApiFailure.fromDioException(error);
    }
  }

  @override
  Future<void> deleteFile(String fileId, {bool permanent = false}) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.delete<dynamic>(
      path: '/files/file/$fileId',
      queryParameters: permanent ? const {'permanent': true} : null,
    );
  }

  @override
  Future<void> restoreFile(String fileId) async {
    await apiBaseService.put<dynamic>(path: '/files/file/$fileId/restore');
  }

  @override
  Future<void> renameFile(String fileId, String name) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.put<dynamic>(
      path: '/files/file/$fileId',
      data: {'file_name': name},
    );
  }

  @override
  Future<void> moveFile(String fileId, String folderId) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.put<dynamic>(
      path: '/files/$fileId/move',
      data: {'folder_id': folderId},
    );
  }

  @override
  Future<FileShareResult> shareFile({
    required String fileId,
    required List<String> recipientIds,
    required FileSharePermission permission,
    required FileShareAccess access,
    String note = '',
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/files/$fileId/share',
      data: {
        'file_id': fileId,
        'access_type': access.apiValue,
        'permission_type': permission.apiValue,
        'note': note,
        'share_via_dm': true,
        'recipient_ids': recipientIds,
      },
    );
    final data = response.data['data'];
    return data is Map
        ? FileShareResult.fromJson(Map<String, dynamic>.from(data))
        : const FileShareResult();
  }

  @override
  Future<Uint8List> fetchFileBytes({
    required String url,
    required int maxBytes,
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final cancel = CancelToken();
    try {
      final response = await downloadClient.get<List<int>>(
        url,
        cancelToken: cancel,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, _) {
          if (received > maxBytes) cancel.cancel(_tooLarge);
        },
      );
      final data = response.data ?? const <int>[];
      if (data.length > maxBytes) throw _tooLargeFailure();
      return data is Uint8List ? data : Uint8List.fromList(data);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) && error.error == _tooLarge) {
        throw _tooLargeFailure();
      }
      throw ApiFailure.fromDioException(error);
    }
  }

  static const _tooLarge = 'too-large';

  static ApiFailure _tooLargeFailure() => const ApiFailure(
    message: 'This file is too large to preview.',
    kind: ApiFailureKind.client,
  );

  @override
  Future<WorkspaceFile> fetchFileDetails(String fileId) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final path = '/files/file/$fileId';
    final response = await apiBaseService.get<Map<String, dynamic>>(path: path);
    final data = response.data['data'];
    if (data is! Map) {
      throw ApiFailure(
        message: 'File details missing from the response.',
        path: path,
        kind: ApiFailureKind.parsing,
      );
    }
    return WorkspaceFile.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<WorkspaceFileInfo> fetchFileInfo(String fileId) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final path = '/files/file/$fileId/info';
    final response = await apiBaseService.get<Map<String, dynamic>>(path: path);
    final data = response.data['data'];
    if (data is! Map) {
      throw ApiFailure(
        message: 'File info missing from the response.',
        path: path,
        kind: ApiFailureKind.parsing,
      );
    }
    return WorkspaceFileInfo.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<Set<String>> fetchPinnedFileIds() async {
    if (config.usesMockData) return const <String>{};
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/files/favorites',
    );
    final raw = response.data['data'];
    return {
      if (raw is List)
        for (final item in raw.whereType<Map<dynamic, dynamic>>())
          ?_pinnedFileId(item),
    };
  }

  /// Each entry is `{pinned_file_id, file: {id, ...}}`.
  static String? _pinnedFileId(Map<dynamic, dynamic> item) {
    final file = item['file'];
    final id = (file is Map ? file['id'] : item['file_id'])?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Future<void> pinFile(String fileId) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.post<dynamic>(path: '/files/file/$fileId/pin');
  }

  @override
  Future<void> unpinFile(String fileId) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.delete<dynamic>(path: '/files/file/$fileId/pin');
  }

  /// Deletes the folder, as the web app does. The server removes the
  /// folder and its contents.
  @override
  Future<void> deleteFolder(String id) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.delete<Map<String, dynamic>>(
      path: '/files/folders/$id',
    );
  }
}
