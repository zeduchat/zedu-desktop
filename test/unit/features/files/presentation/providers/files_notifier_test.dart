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

  test('sorting does not change the query sent to the server', () {
    final before = state().query;
    notifier().setSort(FilesSort.oldestFirst);

    expect(state().sort, FilesSort.oldestFirst);
    expect(state().query, before);
  });

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

    test('shows the top-level Files tab afterwards', () async {
      uploads.read(filesProvider.notifier)
        ..selectView(FilesScope.trash)
        ..openFolder(_docs)
        ..setTab(FilesTab.folders);

      await uploads.read(filesActionsProvider.notifier).uploadFiles([
        _file('a.png'),
      ]);

      final state = uploads.read(filesProvider);
      expect(state.view, FilesScope.all);
      expect(state.folderPath, isEmpty);
      expect(state.tab, FilesTab.files);
    });

    test('an upload from Shared with me shows it in All files', () async {
      uploads.read(filesProvider.notifier).selectView(FilesScope.shared);

      await uploads.read(filesActionsProvider.notifier).uploadFiles([
        _file('a.png'),
      ]);

      expect(uploads.read(filesProvider).view, FilesScope.all);
    });

    test('an upload from My files stays in My files', () async {
      uploads.read(filesProvider.notifier).selectView(FilesScope.mine);

      await uploads.read(filesActionsProvider.notifier).uploadFiles([
        _file('a.png'),
      ]);

      expect(uploads.read(filesProvider).view, FilesScope.mine);
    });
  });
}

class _UploadRepository implements FilesRepository {
  final uploaded = <String>[];

  @override
  Future<Result<WorkspaceFile>> uploadFile(XFile file) async {
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
  }) async => const Success(null);
}
