import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockFilesRepository extends Mock implements FilesRepository {}

const _folder = FileFolder(id: 'folder-1', name: 'Drafts');

void main() {
  late MockFilesRepository repository;
  late ProviderContainer container;

  FolderRenamesNotifier notifier() =>
      container.read(folderRenamesProvider.notifier);

  setUpAll(() => registerFallbackValue(FilesScope.all));

  setUp(() {
    repository = MockFilesRepository();
    container = ProviderContainer(
      overrides: [
        currentOrgIdProvider.overrideWithValue('org-1'),
        filesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    when(
      () => repository.fetchFolders(
        view: any(named: 'view'),
        parentId: any(named: 'parentId'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => const Success(FoldersPage(folders: [])));
  });

  test(
    'renames the folder, trimmed, and reloads the folders (#2719)',
    () async {
      final done = Completer<Result<void>>();
      when(
        () => repository.renameFolder('folder-1', 'Reports'),
      ).thenAnswer((_) => done.future);
      container.listen(foldersListProvider, (_, _) {});
      await container.read(foldersListProvider.future);
      clearInteractions(repository);

      final pending = notifier().rename(_folder, '  Reports ');
      expect(container.read(folderRenamesProvider), {'folder-1'});

      done.complete(const Success(null));
      expect(await pending, isNull);
      expect(container.read(folderRenamesProvider), isEmpty);
      await container.read(foldersListProvider.future);
      verify(
        () => repository.fetchFolders(
          view: any(named: 'view'),
          parentId: any(named: 'parentId'),
          page: any(named: 'page'),
        ),
      ).called(1);
    },
  );

  test('does not call the server for the same or an empty name', () async {
    expect(await notifier().rename(_folder, 'Drafts'), isNull);
    expect(await notifier().rename(_folder, '  '), 'Enter a folder name.');
    verifyNever(() => repository.renameFolder(any(), any()));
  });

  test('explains a failed rename', () async {
    when(() => repository.renameFolder('folder-1', 'Reports')).thenAnswer(
      (_) async => const Failure(
        ApiFailure(message: 'offline', kind: ApiFailureKind.network),
      ),
    );

    expect(
      await notifier().rename(_folder, 'Reports'),
      'Could not rename Drafts. '
      'No internet connection. Check your network and try again.',
    );
    expect(container.read(folderRenamesProvider), isEmpty);
  });
}
