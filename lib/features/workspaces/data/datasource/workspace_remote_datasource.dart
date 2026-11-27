import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract interface class WorkspaceRemoteDataSource {
  /// The organisations the signed-in user belongs to.
  Future<List<Workspace>> getOrganisations();
}

class WorkspaceRemoteDataSourceImpl implements WorkspaceRemoteDataSource {
  WorkspaceRemoteDataSourceImpl({required ApiBaseService apiBaseService})
    : _api = apiBaseService;

  final ApiBaseService _api;

  static const _tag = 'WorkspaceRemoteDataSource';

  @override
  Future<List<Workspace>> getOrganisations() async {
    final response = await _api.get<Map<String, dynamic>>(
      path: '/users/organisations',
    );
    final data = response.data['data'] as List<dynamic>? ?? [];

    final List<Workspace> workspaces = [];
    for (var item in data) {
      if (item is Map<String, dynamic>) {
        final rawId = item['id'];
        final id = rawId is String
            ? rawId.trim()
            : (rawId?.toString().trim() ?? '');
        if (id.isEmpty) {
          // Without an id the workspace cannot be selected or addressed.
          // Skipping it is better than collapsing every id-less
          // organisation onto one shared workspace id.
          AppLogger.w('Skipping organisation without an id', tag: _tag);
          continue;
        }
        workspaces.add(
          Workspace(
            id: id,
            name: item['name'] as String? ?? 'Workspace',
            avatar: item['logo_url'] as String? ?? '',
            membersCount: (item['Users'] as List<dynamic>?)?.length ?? 0,
          ),
        );
      }
    }
    return workspaces;
  }
}
