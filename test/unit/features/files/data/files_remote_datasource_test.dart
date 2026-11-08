import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiBaseService api;
  late MockDio downloadClient;
  late FilesRemoteDataSourceImpl datasource;

  setUp(() {
    api = MockApiBaseService();
    downloadClient = MockDio();
    datasource = FilesRemoteDataSourceImpl(
      apiBaseService: api,
      config: AppConfig(
        apiBaseUrl: 'https://example.test',
        usesMockData: false,
      ),
      downloadClient: downloadClient,
    );
  });

  test('mock build lists no files and makes no request (#3474)', () async {
    final mockDatasource = FilesRemoteDataSourceImpl(
      apiBaseService: api,
      config: AppConfig(apiBaseUrl: 'https://example.test', usesMockData: true),
      downloadClient: downloadClient,
    );

    final page = await mockDatasource.fetchFiles(const FilesQuery());

    expect(page.files, isEmpty);
    verifyNever(
      () => api.get<Map<String, dynamic>>(
        path: any(named: 'path'),
        queryParameters: any(named: 'queryParameters'),
      ),
    );
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

    test('sends the open folder id so the upload lands there', () async {
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
                'id': 'f-10',
                'file_name': 'notes.txt',
                'file_type': 'txt',
                'size': 5,
              },
            ],
          },
        );
      });

      await datasource.uploadFile(
        XFile(file.path, name: 'notes.txt'),
        parentId: 'folder-7',
      );

      final form = sent! as FormData;
      expect(
        form.fields.where((entry) => entry.key == 'folder_id').single.value,
        'folder-7',
      );
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

  group('fetchFileLink', () {
    test('reads the link from the file details', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/file/f-1'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {'file_link': ' https://cdn.zedu.test/logo.png '},
          },
        ),
      );

      expect(
        await datasource.fetchFileLink('f-1'),
        'https://cdn.zedu.test/logo.png',
      );
    });

    test('is empty when the details have no link', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/file/f-1'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': null},
        ),
      );

      expect(await datasource.fetchFileLink('f-1'), isEmpty);
    });
  });

  group('downloadFile', () {
    test('saves the link to the chosen path and reports progress', () async {
      when(
        () => downloadClient.download(
          any(),
          any<dynamic>(),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onReceiveProgress] as ProgressCallback;
        onProgress(50, 100);
        return Response<dynamic>(requestOptions: RequestOptions());
      });
      final progress = <(int, int)>[];

      await datasource.downloadFile(
        url: 'https://cdn.zedu.test/logo.png',
        savePath: '/Users/ada/Downloads/logo.png',
        onProgress: (received, total) => progress.add((received, total)),
      );

      verify(
        () => downloadClient.download(
          'https://cdn.zedu.test/logo.png',
          '/Users/ada/Downloads/logo.png',
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).called(1);
      expect(progress, [(50, 100)]);
    });

    test('turns a failed request into an ApiFailure', () async {
      when(
        () => downloadClient.download(
          any(),
          any<dynamic>(),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/logo.png'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/logo.png'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        datasource.downloadFile(url: 'https://cdn.zedu.test/x', savePath: '/x'),
        throwsA(
          isA<ApiFailure>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  group('deleteFile', () {
    void stubDelete() =>
        when(
          () => api.delete<dynamic>(
            path: any(named: 'path'),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async =>
              const ApiResponseModel<dynamic>(statusCode: 200, data: null),
        );

    test('moves the file to Deleted files', () async {
      stubDelete();

      await datasource.deleteFile('f-1');

      verify(() => api.delete<dynamic>(path: '/files/file/f-1')).called(1);
    });

    test('deletes it for good when permanent', () async {
      stubDelete();

      await datasource.deleteFile('f-1', permanent: true);

      verify(
        () => api.delete<dynamic>(
          path: '/files/file/f-1',
          queryParameters: {'permanent': true},
        ),
      ).called(1);
    });
  });

  group('renameFile', () {
    test('sends the new name', () async {
      when(
        () => api.put<dynamic>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async =>
            const ApiResponseModel<dynamic>(statusCode: 200, data: null),
      );

      await datasource.renameFile('f-1', 'brand.png');

      verify(
        () => api.put<dynamic>(
          path: '/files/file/f-1',
          data: {'file_name': 'brand.png'},
        ),
      ).called(1);
    });
  });

  group('moveFile', () {
    test('sends the target folder', () async {
      when(
        () => api.put<dynamic>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async =>
            const ApiResponseModel<dynamic>(statusCode: 200, data: null),
      );

      await datasource.moveFile('f-1', 'docs');

      verify(
        () => api.put<dynamic>(
          path: '/files/f-1/move',
          data: {'folder_id': 'docs'},
        ),
      ).called(1);
    });
  });

  group('shareFile', () {
    test('sends the share as the web app does and reads the result', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 201,
          data: {
            'data': {
              'share_link': 'https://zedu.chat/share/abc',
              'dms_sent': ['u-2'],
              'recipients_info': [
                {'user_id': 'u-2', 'username': 'grace', 'success': true},
                {
                  'user_id': 'u-3',
                  'username': 'alan',
                  'success': false,
                  'error': 'DM blocked',
                },
              ],
            },
          },
        ),
      );

      final result = await datasource.shareFile(
        fileId: 'f-1',
        recipientIds: ['u-2', 'u-3'],
        permission: FileSharePermission.edit,
        access: FileShareAccess.anyoneWithLink,
        note: 'For the review',
      );

      verify(
        () => api.post<Map<String, dynamic>>(
          path: '/files/f-1/share',
          data: {
            'file_id': 'f-1',
            'access_type': 'public',
            'permission_type': 'edit',
            'note': 'For the review',
            'share_via_dm': true,
            'recipient_ids': ['u-2', 'u-3'],
          },
        ),
      ).called(1);
      expect(result.shareLink, 'https://zedu.chat/share/abc');
      expect(result.sentTo, ['u-2']);
      expect(result.failures.single.userId, 'u-3');
      expect(result.failures.single.error, 'DM blocked');
    });

    test('Only those invited is a private share', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 201,
          data: {'data': null},
        ),
      );

      final result = await datasource.shareFile(
        fileId: 'f-1',
        recipientIds: ['u-2'],
        permission: FileSharePermission.view,
        access: FileShareAccess.invited,
      );

      final sent =
          verify(
                () => api.post<Map<String, dynamic>>(
                  path: '/files/f-1/share',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(sent['access_type'], 'private');
      expect(sent['permission_type'], 'view');
      expect(sent['note'], '');
      expect(result.sentTo, isEmpty);
    });
  });

  group('pins', () {
    test('reads the pinned file ids from the favorites', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/favorites'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': [
              {
                'pinned_file_id': 'p-1',
                'file': {'id': 'f-1', 'file_name': 'logo.png'},
              },
              {'pinned_file_id': 'p-2', 'file_id': 'f-2'},
              {'pinned_file_id': 'p-3', 'file': <String, dynamic>{}},
            ],
          },
        ),
      );

      expect(await datasource.fetchPinnedFileIds(), {'f-1', 'f-2'});
    });

    test('no favorites is no pins', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/favorites'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': null},
        ),
      );

      expect(await datasource.fetchPinnedFileIds(), isEmpty);
    });

    test('pins with POST and unpins with DELETE', () async {
      when(() => api.post<dynamic>(path: any(named: 'path'))).thenAnswer(
        (_) async =>
            const ApiResponseModel<dynamic>(statusCode: 201, data: null),
      );
      when(() => api.delete<dynamic>(path: any(named: 'path'))).thenAnswer(
        (_) async =>
            const ApiResponseModel<dynamic>(statusCode: 200, data: null),
      );

      await datasource.pinFile('f-1');
      await datasource.unpinFile('f-1');

      verify(() => api.post<dynamic>(path: '/files/file/f-1/pin')).called(1);
      verify(() => api.delete<dynamic>(path: '/files/file/f-1/pin')).called(1);
    });
  });

  group('fetchFileDetails', () {
    test('reads the file with its access type', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/file/f-1'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {
              'id': 'f-1',
              'file_name': 'logo.png',
              'file_type': 'png',
              'size': 2048,
              'folder_id': 'docs',
              'access_type': 'Public',
              'created_at': '2026-10-30T14:05:00Z',
            },
          },
        ),
      );

      final file = await datasource.fetchFileDetails('f-1');

      expect(file.name, 'logo.png');
      expect(file.size, 2048);
      expect(file.folderId, 'docs');
      expect(file.accessType, 'public');
      expect(file.createdAt, DateTime.utc(2026, 10, 30, 14, 5).toLocal());
    });

    test('a response without the file is a parsing failure', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/file/f-1'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': null},
        ),
      );

      expect(
        datasource.fetchFileDetails('f-1'),
        throwsA(
          isA<ApiFailure>().having(
            (f) => f.kind,
            'kind',
            ApiFailureKind.parsing,
          ),
        ),
      );
    });
  });

  group('fetchFileInfo', () {
    test('reads the channels the file was shared in', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/file/f-1/info'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {
              'owner': 'Ada Lovelace',
              'date_uploaded': '2026-10-30T14:05:00Z',
              'last_updated': '2026-11-01T09:00:00Z',
              'shared_in': ['general', 'design'],
            },
          },
        ),
      );

      final info = await datasource.fetchFileInfo('f-1');

      expect(info.owner, 'Ada Lovelace');
      expect(info.sharedIn, ['general', 'design']);
      expect(info.sharedInLabel, 'general, design');
      expect(info.dateUploaded, DateTime.utc(2026, 10, 30, 14, 5).toLocal());
    });

    test('a file shared nowhere has no channels', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/file/f-1/info'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {'owner': 'Ada Lovelace', 'shared_in': <String>[]},
          },
        ),
      );

      final info = await datasource.fetchFileInfo('f-1');

      expect(info.sharedIn, isEmpty);
      expect(info.sharedInLabel, isEmpty);
    });

    test('a response without the info is a parsing failure', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/file/f-1/info'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': null},
        ),
      );

      expect(
        datasource.fetchFileInfo('f-1'),
        throwsA(
          isA<ApiFailure>().having(
            (f) => f.kind,
            'kind',
            ApiFailureKind.parsing,
          ),
        ),
      );
    });
  });

  group('fetchFileBytes', () {
    test('returns the contents without the session client', () async {
      when(
        () => downloadClient.get<List<int>>(
          'https://files.zedu.test/notes.txt',
          cancelToken: any(named: 'cancelToken'),
          options: any(named: 'options'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer(
        (_) async =>
            Response(requestOptions: RequestOptions(), data: [104, 105]),
      );

      final bytes = await datasource.fetchFileBytes(
        url: 'https://files.zedu.test/notes.txt',
        maxBytes: 10,
      );

      expect(bytes, [104, 105]);
      verifyNever(() => api.get<dynamic>(path: any(named: 'path')));
    });

    test('refuses contents larger than the limit', () async {
      when(
        () => downloadClient.get<List<int>>(
          any(),
          cancelToken: any(named: 'cancelToken'),
          options: any(named: 'options'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: List.filled(11, 0),
        ),
      );

      expect(
        datasource.fetchFileBytes(url: 'https://x.test/a', maxBytes: 10),
        throwsA(
          isA<ApiFailure>()
              .having((f) => f.kind, 'kind', ApiFailureKind.client)
              .having(
                (f) => f.message,
                'message',
                'This file is too large to preview.',
              ),
        ),
      );
    });
  });

  group('restoreFile', () {
    test('restores the file from Deleted files', () async {
      when(() => api.put<dynamic>(path: any(named: 'path'))).thenAnswer(
        (_) async =>
            const ApiResponseModel<dynamic>(statusCode: 200, data: null),
      );

      await datasource.restoreFile('f-1');

      verify(() => api.put<dynamic>(path: '/files/file/f-1/restore')).called(1);
    });
  });
}
