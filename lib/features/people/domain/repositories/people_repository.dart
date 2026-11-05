import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class PeopleRepository {
  /// One page of the workspace's members, filtered by [search] when it is
  /// not empty.
  Future<Result<MembersPage>> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  });
}
