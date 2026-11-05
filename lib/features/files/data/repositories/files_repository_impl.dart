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
  Future<Result<WorkspaceFile>> uploadFile(XFile file) =>
      _guard(() => remoteDataSource.uploadFile(file));

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

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Success(await call());
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }
}
