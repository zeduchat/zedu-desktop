import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockFilesRepository extends Mock implements FilesRepository {}

const _file = WorkspaceFile(id: 'f-1', name: 'logo.png');

void main() {
  late MockFilesRepository repository;
  late ProviderContainer container;

  FileRestoresNotifier notifier() =>
      container.read(fileRestoresProvider.notifier);

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
      () => repository.fetchFiles(any()),
    ).thenAnswer((_) async => const Success(FilesPage(files: [])));
  });

  setUpAll(() => registerFallbackValue(const FilesQuery(view: FilesScope.all)));

  test('restores the file and reloads the list', () async {
    final done = Completer<Result<void>>();
    when(() => repository.restoreFile('f-1')).thenAnswer((_) => done.future);
    container.listen(filesListProvider, (_, _) {});
    await container.read(filesListProvider.future);
    clearInteractions(repository);

    final pending = notifier().restore(_file);
    expect(container.read(fileRestoresProvider), {'f-1'});

    done.complete(const Success(null));
    expect(await pending, isNull);
    expect(container.read(fileRestoresProvider), isEmpty);
    await container.read(filesListProvider.future);
    verify(() => repository.fetchFiles(any())).called(1);
  });

  test('ignores a second restore while one is running', () async {
    final done = Completer<Result<void>>();
    when(() => repository.restoreFile('f-1')).thenAnswer((_) => done.future);

    final first = notifier().restore(_file);
    expect(await notifier().restore(_file), isNull);
    done.complete(const Success(null));
    await first;

    verify(() => repository.restoreFile('f-1')).called(1);
  });

  test('explains a failed restore', () async {
    when(() => repository.restoreFile('f-1')).thenAnswer(
      (_) async => const Failure(
        ApiFailure(message: 'nope', kind: ApiFailureKind.forbidden),
      ),
    );

    expect(
      await notifier().restore(_file),
      'Could not restore logo.png. You don\'t have permission to do that.',
    );
    expect(container.read(fileRestoresProvider), isEmpty);
  });
}
