import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class PeopleRepositoryImpl implements PeopleRepository {
  final PeopleRemoteDataSource remoteDataSource;

  PeopleRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<MembersPage>> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  }) async {
    try {
      return Success(
        await remoteDataSource.fetchMembers(
          orgId: orgId,
          page: page,
          search: search,
        ),
      );
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }
}
