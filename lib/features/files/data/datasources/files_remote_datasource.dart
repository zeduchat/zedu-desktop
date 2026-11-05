import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class FilesRemoteDataSource {
  Future<FilesPage> fetchFiles(FilesQuery query);

  Future<FoldersPage> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  });

  Future<WorkspaceFile> uploadFile(XFile file);

  Future<void> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  });
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

  FilesRemoteDataSourceImpl({required this.apiBaseService});

  /// Folders per page, as the web app asks for.
  static const pageSize = 10;

  @override
  Future<FilesPage> fetchFiles(FilesQuery query) async {
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
  Future<WorkspaceFile> uploadFile(XFile file) async {
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
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/files/folders',
      data: {
        'name': name,
        'parent_id': parentId != null && parentId.isNotEmpty ? parentId : null,
        'organisation_id': orgId,
      },
    );
  }
}
