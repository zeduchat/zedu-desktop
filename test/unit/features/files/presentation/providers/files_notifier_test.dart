import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

const _docs = FileFolder(id: 'docs', name: 'docs');
const _drafts = FileFolder(id: 'drafts', name: 'drafts');

/// A file in the temp folder. On desktop XFile takes its name from the
/// path, split on the platform's separator, so the path must use it.
XFile _file(String name) =>
    XFile('${Directory.systemTemp.path}${Platform.pathSeparator}$name');

void main() {
  late ProviderContainer container;
  FilesNotifier notifier() => container.read(filesProvider.notifier);
  FilesState state() => container.read(filesProvider);

  setUp(() {
    container = ProviderContainer(
      overrides: [currentOrgIdProvider.overrideWithValue('org-1')],
    );
    addTearDown(container.dispose);
  });

  test('opening a folder shows its files from the first page', () {
    notifier().setPage(3);
    notifier().openFolder(_docs);

    expect(state().folderId, 'docs');
    expect(state().tab, FilesTab.files);
    expect(state().page, 1);
  });

  test('going back to a level drops the folders below it', () {
    notifier()
      ..openFolder(_docs)
      ..openFolder(_drafts);

    notifier().goToDepth(1);
    expect(state().folderPath, [_docs]);

    notifier().goToDepth(0);
    expect(state().folderId, isNull);
  });

  test('picking a sidebar list leaves the open folder', () {
    notifier().openFolder(_docs);
    notifier().selectView(FilesScope.trash);

    expect(state().view, FilesScope.trash);
    expect(state().folderPath, isEmpty);
  });

  test('filters go back to the first page and can be cleared', () {
    notifier().setPage(2);
    notifier().setCategory(FileCategory.images);
    expect(state().page, 1);
    expect(state().query.category, FileCategory.images);

    notifier().setCategory(null);
    expect(state().category, isNull);

    notifier().setDateModified(DateModifiedFilter.thisYear);
    notifier().setSearch('logo');
    expect(state().query.dateModified, DateModifiedFilter.thisYear);
    expect(state().query.search, 'logo');
  });

  group('Reset filters (Ziki #3445)', () {
    test('clears search, type and date together, keeping the rest', () {
      notifier()
        ..selectView(FilesScope.mine)
        ..openFolder(const FileFolder(id: 'f1', name: 'Reports'))
        ..setTab(FilesTab.files)
        ..setSort(FilesSort.oldestFirst)
        ..setCategory(FileCategory.images)
        ..setDateModified(DateModifiedFilter.today)
        ..setSearch('logo')
        ..setPage(3);
      expect(state().hasFilters, isTrue);

      notifier().resetFilters();

      expect(state().category, isNull);
      expect(state().dateModified, isNull);
      expect(state().search, '');
      expect(state().hasFilters, isFalse);
      expect(state().page, 1);
      expect(state().view, FilesScope.mine);
      expect(state().folderId, 'f1');
      expect(state().tab, FilesTab.files);
      expect(state().sort, FilesSort.oldestFirst);
    });

    test('changes state once, so the list refreshes once', () {
      notifier()
        ..setCategory(FileCategory.images)
        ..setSearch('logo');
      var changes = 0;
      final sub = container.listen(filesProvider, (_, _) => changes++);
      addTearDown(sub.close);

      notifier().resetFilters();

      expect(changes, 1);
    });

    test('does nothing when no filter is set', () {
      final before = state();

      notifier().resetFilters();

      expect(identical(state(), before), isTrue);
    });

    test('a search of only spaces is not a filter', () {
      notifier().setSearch('   ');

      expect(state().hasFilters, isFalse);
    });
  });

  test('sorting goes back to the first page without changing the request', () {
    notifier().setPage(2);
    final before = state().query;
    notifier().setSort(FilesSort.oldestFirst);

    expect(state().sort, FilesSort.oldestFirst);
    expect(state().page, 1);
    // The sort is applied by the client; the server is still asked for the
    // same filters, at page 1.
    expect(state().query, isNot(before));
    expect(
      state().query.toQueryParameters(),
      before.copyWith(page: 1).toQueryParameters(),
    );
  });

  group('the files list', () {
    late _PagedRepository repository;
    late ProviderContainer files;

    FilesNotifier filesNotifier() => files.read(filesProvider.notifier);

    setUp(() {
      repository = _PagedRepository();
      files = ProviderContainer(
        overrides: [
          currentOrgIdProvider.overrideWithValue('org-1'),
          filesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(files.dispose);
    });

    test('newest first reads the page the user asked for', () async {
      filesNotifier().setPage(2);
      final page = await files.read(filesListProvider.future);

      expect(repository.pages, [2]);
      expect(page.currentPage, 2);
    });

    test('oldest first reads the server pages backwards', () async {
      repository.totalPages = 3;
      filesNotifier().setSort(FilesSort.oldestFirst);
      final page = await files.read(filesListProvider.future);

      expect(repository.pages, [1, 3]);
      expect(page.currentPage, 1);
      expect(page.totalPages, 3);
      expect(page.files.map((file) => file.id), [
        for (var i = 1; i <= 10; i++) 'p3-$i',
      ]);
    });

    test('the next page is the server page before the last one', () async {
      repository.totalPages = 3;
      filesNotifier().setSort(FilesSort.oldestFirst);
      await files.read(filesListProvider.future);

      filesNotifier().setPage(2);
      final page = await files.read(filesListProvider.future);

      expect(repository.pages.last, 2);
      expect(page.currentPage, 2);
      expect(page.files.first.id, 'p2-1');
    });
  });

  for (final (kind, expected) in [
    (
      ApiFailureKind.network,
      'No internet connection. Check your network and try again.',
    ),
    (
      ApiFailureKind.server,
      'Something went wrong on our end. Please try again later.',
    ),
    (ApiFailureKind.unknown, 'Could not create the folder. Try again.'),
    (ApiFailureKind.parsing, 'Could not create the folder. Try again.'),
    (ApiFailureKind.client, 'Folder name already exists'),
  ]) {
    test(
      'create-folder failure $kind returns safe copy and clears loading',
      () async {
        final repository = _UploadRepository()
          ..folderError = ApiFailure(
            message: kind == ApiFailureKind.client
                ? 'Folder name already exists'
                : '<html>internal-host failure</html>',
            kind: kind,
          );
        final folders = ProviderContainer(
          overrides: [
            currentOrgIdProvider.overrideWithValue('org-1'),
            filesRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(folders.dispose);
        final message = await folders
            .read(filesActionsProvider.notifier)
            .createFolder('docs');
        expect(message, expected);
        expect(folders.read(filesActionsProvider).isCreatingFolder, isFalse);
      },
    );
  }

  group('uploadFiles', () {
    late ProviderContainer uploads;
    late _UploadRepository repository;

    setUp(() {
      repository = _UploadRepository();
      uploads = ProviderContainer(
        overrides: [
          currentOrgIdProvider.overrideWithValue('org-1'),
          filesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(uploads.dispose);
    });

    test('uploads each file and reports the failures', () async {
      final outcome = await uploads
          .read(filesActionsProvider.notifier)
          .uploadFiles([_file('a.png'), _file('bad.pdf'), _file('c.txt')]);

      expect(repository.uploaded, ['a.png', 'bad.pdf', 'c.txt']);
      expect(outcome.uploaded, 2);
      expect(outcome.failedNames, ['bad.pdf']);
      expect(uploads.read(filesActionsProvider).isUploading, isFalse);
    });

    test(
      'keeps the open folder afterwards so the uploads are visible',
      () async {
        uploads.read(filesProvider.notifier)
          ..selectView(FilesScope.trash)
          ..openFolder(_docs)
          ..setTab(FilesTab.folders);

        await uploads.read(filesActionsProvider.notifier).uploadFiles([
          _file('a.png'),
        ]);

        final state = uploads.read(filesProvider);
        expect(state.view, FilesScope.all);
        // The old behaviour jumped to the top level, leaving the user staring at
        // a folder that looked empty because the file landed at the root.
        expect(state.folderPath, isNotEmpty);
        expect(state.folderId, isNotNull);
        expect(state.tab, FilesTab.files);
      },
    );
  });
}

/// Server pages of ten files, newest first: page 1 holds the newest files and
/// every later page holds older ones.
class _PagedRepository extends Fake implements FilesRepository {
  int totalPages = 1;
  final pages = <int>[];

  @override
  Future<Result<WorkspaceFileInfo>> fetchFileInfo(String fileId) async =>
      Success(WorkspaceFileInfo());

  @override
  Future<Result<FilesPage>> fetchFiles(FilesQuery query) async {
    pages.add(query.page);
    return Success(
      FilesPage(
        files: [
          for (var i = 10; i >= 1; i--)
            WorkspaceFile(
              id: 'p${query.page}-$i',
              name: 'p${query.page}-$i',
              updatedAt: DateTime(
                2026,
                1,
                1,
              ).add(Duration(days: (query.page - 1) * 10 + i)),
            ),
        ],
        currentPage: query.page,
        totalPages: totalPages,
      ),
    );
  }

  @override
  Future<Result<FoldersPage>> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  }) async => const Success(FoldersPage(folders: []));

  @override
  Future<Result<WorkspaceFile>> uploadFile(
    XFile file, {
    String? parentId,
  }) async => Success(WorkspaceFile(id: file.name, name: file.name));

  @override
  Future<Result<void>> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  }) async => const Success(null);

  @override
  Future<Result<void>> downloadFile({
    required WorkspaceFile file,
    required String savePath,
    void Function(double? progress)? onProgress,
  }) async => const Success(null);

  @override
  Future<Result<void>> deleteFile(
    String fileId, {
    bool permanent = false,
  }) async => const Success(null);

  @override
  Future<Result<void>> renameFile(String fileId, String name) async =>
      const Success(null);

  @override
  Future<Result<void>> moveFile(String fileId, String folderId) async =>
      const Success(null);

  @override
  Future<Result<FileShareResult>> shareFile({
    required String fileId,
    required List<String> recipientIds,
    required FileSharePermission permission,
    required FileShareAccess access,
    String note = '',
  }) async => const Success(FileShareResult());

  @override
  Future<Result<Uint8List>> fetchFilePreview(
    WorkspaceFile file,
    FilePreviewKind kind,
  ) async => Success(Uint8List(0));

  @override
  Future<Result<WorkspaceFile>> fetchFileDetails(String fileId) async =>
      Success(WorkspaceFile(id: fileId, name: fileId));

  @override
  Future<Result<Set<String>>> fetchPinnedFileIds() async => const Success({});

  @override
  Future<Result<void>> pinFile(String fileId) async => const Success(null);

  @override
  Future<Result<void>> unpinFile(String fileId) async => const Success(null);

  @override
  Future<Result<void>> deleteFolder(String id) async => const Success(null);
}

class _UploadRepository extends Fake implements FilesRepository {
  final uploaded = <String>[];
  ApiFailure? folderError;

  @override
  Future<Result<WorkspaceFile>> uploadFile(
    XFile file, {
    String? parentId,
  }) async {
    uploaded.add(file.name);
    return file.name.startsWith('bad')
        ? const Failure(ApiFailure(message: 'too large'))
        : Success(WorkspaceFile(id: file.name, name: file.name));
  }

  @override
  Future<Result<FilesPage>> fetchFiles(FilesQuery query) async =>
      const Success(FilesPage(files: []));

  @override
  Future<Result<FoldersPage>> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  }) async => const Success(FoldersPage(folders: []));

  @override
  Future<Result<void>> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  }) async => folderError == null ? const Success(null) : Failure(folderError!);

  @override
  Future<Result<void>> downloadFile({
    required WorkspaceFile file,
    required String savePath,
    void Function(double? progress)? onProgress,
  }) async => const Success(null);

  @override
  Future<Result<void>> deleteFile(
    String fileId, {
    bool permanent = false,
  }) async => const Success(null);

  @override
  Future<Result<void>> renameFile(String fileId, String name) async =>
      const Success(null);

  @override
  Future<Result<void>> moveFile(String fileId, String folderId) async =>
      const Success(null);

  @override
  Future<Result<FileShareResult>> shareFile({
    required String fileId,
    required List<String> recipientIds,
    required FileSharePermission permission,
    required FileShareAccess access,
    String note = '',
  }) async => const Success(FileShareResult());

  @override
  Future<Result<Uint8List>> fetchFilePreview(
    WorkspaceFile file,
    FilePreviewKind kind,
  ) async => Success(Uint8List(0));

  @override
  Future<Result<WorkspaceFile>> fetchFileDetails(String fileId) async =>
      Success(WorkspaceFile(id: fileId, name: fileId));

  @override
  Future<Result<WorkspaceFileInfo>> fetchFileInfo(String fileId) async =>
      Success(WorkspaceFileInfo());

  @override
  Future<Result<Set<String>>> fetchPinnedFileIds() async => const Success({});

  @override
  Future<Result<void>> pinFile(String fileId) async => const Success(null);

  @override
  Future<Result<void>> unpinFile(String fileId) async => const Success(null);

  @override
  Future<Result<void>> deleteFolder(String id) async => const Success(null);
}
