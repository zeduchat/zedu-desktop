import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late FilesRemoteDataSourceImpl datasource;

  setUp(() {
    api = MockApiBaseService();
    datasource = FilesRemoteDataSourceImpl(apiBaseService: api);
  });

  group('fetchFiles', () {
    test('sends the query and reads files and pagination', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/files',
          queryParameters: {
            'mode': 'mine',
            'page': 2,
            'limit': 10,
            'folder_id': 'folder-1',
            'file_category': 'images',
            'date_modified': 'last_7_days',
            'search': 'logo',
          },
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {
              'files': [
                {
                  'id': 'f-1',
                  'file_name': 'logo.png',
                  'file_type': 'png',
                  'file_link': 'https://cdn.zedu.test/logo.png',
                  'size': 2048,
                  'user_id': 'u-1',
                  'uploader_display_name': 'Ada Lovelace',
                  'shared_in': 'general',
                  'updated_at': '2026-11-01T10:00:00Z',
                },
              ],
              'pagination': {'current_page': 2, 'total_pages_count': 3},
            },
          },
        ),
      );

      final page = await datasource.fetchFiles(
        const FilesQuery(
          view: FilesScope.mine,
          folderId: 'folder-1',
          category: FileCategory.images,
          dateModified: DateModifiedFilter.last7Days,
          search: ' logo ',
          page: 2,
        ),
      );

      expect(page.currentPage, 2);
      expect(page.totalPages, 3);
      final file = page.files.single;
      expect(file.name, 'logo.png');
      expect(file.isImage, isTrue);
      expect(file.size, 2048);
      expect(file.owner, 'Ada Lovelace');
      expect(file.sharedIn, 'general');
      expect(file.modifiedAt, DateTime.utc(2026, 11, 1, 10).toLocal());
    });

    test('returns an empty page when the body has no files', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/files',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': null},
        ),
      );

      final page = await datasource.fetchFiles(const FilesQuery());

      expect(page.files, isEmpty);
      expect(page.totalPages, 1);
    });
  });

  group('fetchFolders', () {
    test('asks for the folders inside a parent', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/files/folders',
          queryParameters: {
            'mode': 'trash',
            'page': 2,
            'limit': 10,
            'parent_id': 'folder-1',
          },
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {
              'folders': [
                {
                  'id': 'folder-2',
                  'name': 'docs',
                  'user_id': 'u-1',
                  'item_count': 4,
                  'created_at': '2026-11-01T00:00:00Z',
                },
              ],
              'pagination': {'current_page': 2, 'total_pages': 4},
            },
          },
        ),
      );

      final page = await datasource.fetchFolders(
        view: FilesScope.trash,
        parentId: 'folder-1',
        page: 2,
      );

      expect(page.folders.single.name, 'docs');
      expect(page.folders.single.itemCount, 4);
      expect(page.currentPage, 2);
      expect(page.totalPages, 4);
    });

    test('leaves out parent_id at the top level', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/files/folders',
          queryParameters: {'mode': 'all', 'page': 1, 'limit': 10},
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {'folders': <dynamic>[]},
          },
        ),
      );

      final page = await datasource.fetchFolders(view: FilesScope.all);
      expect(page.folders, isEmpty);
      expect(page.totalPages, 1);
    });
  });

  group('uploadFile', () {
    late File file;

    setUp(() {
      final dir = Directory.systemTemp.createTempSync('files_upload_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      // The platform's separator, so XFile.name reads `notes.txt` on Windows
      // too.
      file = File('${dir.path}${Platform.pathSeparator}notes.txt')
        ..writeAsStringSync('hello');
    });

    test('posts the file as the files part and reads the result', () async {
      Object? sent;
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/files/upload-files',
          data: any(named: 'data'),
        ),
      ).thenAnswer((invocation) async {
        sent = invocation.namedArguments[#data];
        return const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': [
              {
                'id': 'f-9',
                'file_name': 'notes.txt',
                'file_type': 'txt',
                'size': 5,
              },
            ],
          },
        );
      });

      final uploaded = await datasource.uploadFile(
        XFile(file.path, name: 'notes.txt'),
      );

      expect(uploaded.id, 'f-9');
      expect(uploaded.name, 'notes.txt');
      final form = sent! as FormData;
      expect(form.files.single.key, 'files');
      expect(form.files.single.value.filename, 'notes.txt');
    });

    test('throws when the server returns no file', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/files/upload-files',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': <dynamic>[]},
        ),
      );

      expect(
        () => datasource.uploadFile(XFile(file.path, name: 'notes.txt')),
        throwsA(isA<ApiFailure>()),
      );
    });
  });

  group('createFolder', () {
    test('sends the name, parent and organisation', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/files/folders',
          data: {
            'name': 'Reports',
            'parent_id': 'folder-1',
            'organisation_id': 'org-1',
          },
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 201,
          data: {},
        ),
      );

      await datasource.createFolder(
        name: 'Reports',
        orgId: 'org-1',
        parentId: 'folder-1',
      );
    });

    test('sends a null parent at the top level', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/files/folders',
          data: {
            'name': 'Reports',
            'parent_id': null,
            'organisation_id': 'org-1',
          },
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 201,
          data: {},
        ),
      );

      await datasource.createFolder(name: 'Reports', orgId: 'org-1');
    });
  });
}
