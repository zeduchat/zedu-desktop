import '../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

// Shaped like GET /organisations/{orgId}/roles on the Zedu backend.
ApiResponseModel<Map<String, dynamic>> _roles() {
  return const ApiResponseModel(
    data: <String, dynamic>{
      'data': [
        {
          'id': 'role-1',
          'name': 'Admin',
          'description': 'Runs the workspace',
          'is_default': true,
          'permissions': {
            'id': 'perm-1',
            'role_id': 'role-1',
            'permission_list': {
              'can_manage_channels': true,
              'can_invite_members': true,
              'can_manage_billing': false,
            },
          },
        },
        {
          'id': 'role-2',
          'name': 'Guest',
          'description': 'Reads channels',
          'permissions': {'permission_list': <String, dynamic>{}},
        },
      ],
    },
    statusCode: 200,
  );
}

void main() {
  group(
    'UserProfileRemoteDataSourceImpl.getRolesAndPermissions (Ziki #2857)',
    () {
      late MockApiBaseService api;
      late UserProfileRemoteDataSourceImpl dataSource;

      setUp(() {
        api = MockApiBaseService();
        dataSource = UserProfileRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.example.com',
            usesMockData: false,
          ),
          apiBaseService: api,
        );
        when(
          () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
        ).thenAnswer((_) async => _roles());
      });

      test('loads the selected organisation\'s roles', () async {
        await dataSource.getRolesAndPermissions(orgId: 'org-1');

        verify(
          () =>
              api.get<Map<String, dynamic>>(path: '/organisations/org-1/roles'),
        ).called(1);
        verifyNever(
          () => api.get<Map<String, dynamic>>(
            path: '/profile/organization/roles',
          ),
        );
      });

      test('reads the real names, descriptions and permissions', () async {
        final roles = await dataSource.getRolesAndPermissions(orgId: 'org-1');

        expect(roles.map((r) => r.role), ['Admin', 'Guest']);
        expect(roles.first.description, 'Runs the workspace');
        expect(roles.first.permissions, ['Manage channels', 'Invite members']);
        expect(roles.last.permissions, isEmpty);
      });

      test('asks for nothing when no organisation is selected', () async {
        final roles = await dataSource.getRolesAndPermissions();

        expect(roles, isEmpty);
        verifyNever(
          () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
        );
      });
    },
  );

  group('RolePermissionModel.fromJson', () {
    test('still reads the older role/permission-list shape', () {
      final role = RolePermissionModel.fromJson(const {
        'role': 'Manager',
        'description': 'Leads a team',
        'permissions': ['Create channels'],
      });

      expect(role.role, 'Manager');
      expect(role.permissions, ['Create channels']);
    });
  });
}
