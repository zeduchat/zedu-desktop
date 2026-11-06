import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _DeferredUploads implements FilesRepository {
  String workspace = 'A';
  final destinations = <String>[];
  final first = Completer<Result<WorkspaceFile>>();

  @override
  Future<Result<WorkspaceFile>> uploadFile(
    XFile file, {
    String? parentId,
  }) {
    destinations.add(workspace);
    if (destinations.length == 1) return first.future;
    return Future.value(Success(WorkspaceFile(id: file.name, name: file.name)));
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

  @override
  Future<Result<void>> deleteFolder(String id) async => const Success(null);

  @override
  Future<Result<void>> deleteFile(String fileId, {bool permanent = false}) async => const Success(null);

  @override
  Future<Result<void>> downloadFile({
    required WorkspaceFile file,
    required String savePath,
    void Function(double? progress)? onProgress,
  }) async => const Success(null);

  @override
  Future<Result<void>> renameFile(String fileId, String name) async => const Success(null);

  @override
  Future<Result<void>> moveFile(String fileId, String folderId) async => const Success(null);

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
      Success(WorkspaceFile(id: fileId, name: 'file', size: 0));

  @override
  Future<Result<Set<String>>> fetchPinnedFileIds() async => const Success({});

  @override
  Future<Result<void>> pinFile(String fileId) async => const Success(null);

  @override
  Future<Result<void>> unpinFile(String fileId) async => const Success(null);
}

void main() {
  late _DeferredUploads repository;
  late ProviderContainer container;

  void switchWorkspace(String workspace) {
    repository.workspace = workspace;
    container.updateOverrides([
      currentOrgIdProvider.overrideWithValue(workspace),
      filesRepositoryProvider.overrideWithValue(repository),
    ]);
    container.read(currentOrgIdProvider);
  }

  Future<FilesUploadOutcome> startBatch() => container
      .read(filesActionsProvider.notifier)
      .uploadFiles([XFile('first.txt'), XFile('second.txt')]);

  void completeFirst() => repository.first.complete(
    const Success(WorkspaceFile(id: 'first', name: 'first.txt')),
  );

  setUp(() {
    repository = _DeferredUploads();
    container = ProviderContainer(
      overrides: [
        currentOrgIdProvider.overrideWithValue('A'),
        filesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'workspace switch stops remaining files from uploading elsewhere',
    () async {
      final upload = startBatch();
      expect(repository.destinations, ['A']);
      switchWorkspace('B');
      completeFirst();
      final outcome = await upload;

      expect(
        repository.destinations,
        ['A'],
        reason: 'Do not send remaining files to workspace B.',
      );
      expect(outcome.uploaded, 1);
      expect(outcome.skippedNames, ['second.txt']);
      expect(outcome.failedNames, isEmpty);
      expect(outcome.workspaceChanged, isTrue);
      expect(container.read(filesActionsProvider).isUploading, isFalse);

      await container.read(filesActionsProvider.notifier).uploadFiles([
        XFile('new-batch.txt'),
      ]);
      expect(repository.destinations, ['A', 'B']);
    },
  );

  test('switching away and back still stops the original batch', () async {
    final upload = startBatch();
    switchWorkspace('B');
    switchWorkspace('A');
    completeFirst();
    final outcome = await upload;

    expect(repository.destinations, ['A']);
    expect(outcome.workspaceChanged, isTrue);
    expect(outcome.skippedNames, ['second.txt']);
  });

  test('old completion preserves the new workspace folder and tab', () async {
    final upload = startBatch();
    switchWorkspace('B');
    container.read(filesProvider.notifier)
      ..openFolder(const FileFolder(id: 'b-folder', name: 'B folder'))
      ..setTab(FilesTab.folders)
      ..setPage(3);
    completeFirst();
    await upload;

    final state = container.read(filesProvider);
    expect(state.folderId, 'b-folder');
    expect(state.tab, FilesTab.folders);
    expect(state.page, 3);
  });

  test('same workspace uploads the whole batch normally', () async {
    final upload = startBatch();
    completeFirst();
    final outcome = await upload;

    expect(repository.destinations, ['A', 'A']);
    expect(outcome.uploaded, 2);
    expect(outcome.workspaceChanged, isFalse);
    expect(outcome.skippedNames, isEmpty);
    expect(container.read(filesActionsProvider).isUploading, isFalse);
  });

  test('switch on the last file also preserves new navigation', () async {
    final upload = container.read(filesActionsProvider.notifier).uploadFiles([
      XFile('first.txt'),
    ]);
    switchWorkspace('B');
    container.read(filesProvider.notifier).setTab(FilesTab.folders);
    completeFirst();
    final outcome = await upload;

    expect(outcome.workspaceChanged, isTrue);
    expect(outcome.skippedNames, isEmpty);
    expect(container.read(filesProvider).tab, FilesTab.folders);
  });

  test(
    'disposing during a pending upload does not mutate disposed state',
    () async {
      final disposable = ProviderContainer(
        overrides: [
          currentOrgIdProvider.overrideWithValue('A'),
          filesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final upload = disposable.read(filesActionsProvider.notifier).uploadFiles(
        [XFile('first.txt'), XFile('second.txt')],
      );
      disposable.dispose();
      completeFirst();
      await upload;
      expect(repository.destinations, ['A']);
    },
  );
}
