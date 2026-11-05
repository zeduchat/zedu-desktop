import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class PeopleRemoteDataSource {
  Future<MembersPage> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  });
}

/// Lists members the way the web app's `useOrganisationUsers` does.
class PeopleRemoteDataSourceImpl implements PeopleRemoteDataSource {
  final ApiBaseService apiBaseService;

  PeopleRemoteDataSourceImpl({required this.apiBaseService});

  /// Members per page, as the web app asks for.
  static const pageSize = 50;

  @override
  Future<MembersPage> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  }) async {
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/organisations/$orgId/users',
      queryParameters: {
        'page': page,
        'limit': pageSize,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final body = response.data;
    final raw = body['data'];
    final members = (raw is List ? raw : const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => OrgMember.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.id.isNotEmpty)
        .toList();

    // The pagination is an object, or a list holding one.
    var pagination = body['pagination'];
    if (pagination is List) {
      pagination = pagination.isEmpty ? null : pagination.first;
    }
    int? value(String key) => pagination is Map
        ? num.tryParse(pagination[key]?.toString() ?? '')?.toInt()
        : null;

    final currentPage = value('current_page') ?? page;
    // Without pagination, a full page means there may be more.
    final totalPages =
        value('total_pages') ??
        (members.length >= pageSize ? currentPage + 1 : currentPage);
    final totalItems =
        value('total_items') ?? (page - 1) * pageSize + members.length;
    return MembersPage(
      members: members,
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalItems: totalItems < 0 ? 0 : totalItems,
    );
  }
}
