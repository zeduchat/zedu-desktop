import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('UserProfileRemoteDataSourceImpl.deleteAccount (Ziki #584)', () {
    late MockApiBaseService api;
    late UserProfileRemoteDataSourceImpl datasource;

    setUp(() {
      api = MockApiBaseService();
      datasource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
        apiBaseService: api,
      );
      when(
        () => api.delete<Map<String, dynamic>>(path: '/users/me'),
      ).thenAnswer(
        (_) async => ApiResponseModel<Map<String, dynamic>>(
          data: const <String, dynamic>{},
          statusCode: 200,
        ),
      );
    });

    test('deactivates the account with DELETE /users/me', () async {
      await datasource.deleteAccount();

      verify(
        () => api.delete<Map<String, dynamic>>(path: '/users/me'),
      ).called(1);
    });

    test('never calls the non-existent /profile/account route', () async {
      await datasource.deleteAccount();

      verifyNever(
        () => api.delete<Map<String, dynamic>>(path: '/profile/account'),
      );
    });
  });

  group('UserProfileRemoteDataSourceImpl.getTeamMembers', () {
    test('lists the organisation users with their real names', () async {
      final mockApi = MockApiBaseService();
      final datasource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(apiBaseUrl: '', usesMockData: false),
        apiBaseService: mockApi,
      );
      const orgId = '019700db-4e22-7f90-a20e-f9116291ef24';
      when(
        () => mockApi.get<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': [
              {'id': 'u1', 'email': 'a@zedu.chat', 'full_name': 'Alice Ade'},
              {'id': 'u2', 'email': 'b@zedu.chat', 'username': 'bobby'},
              {'id': 'u3', 'email': 'carol@zedu.chat', 'full_name': ' '},
            ],
          },
        ),
      );

      final members = await datasource.getTeamMembers(orgId: orgId);

      verify(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/$orgId/users',
        ),
      ).called(1);
      expect(members.map((m) => m.name), ['Alice Ade', 'bobby', 'carol']);
    });
  });

  group('UserProfileRemoteDataSourceImpl.getRolesAndPermissions (#720)', () {
    late MockApiBaseService mockApi;
    late UserProfileRemoteDataSourceImpl datasource;

    setUp(() {
      mockApi = MockApiBaseService();
      datasource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(apiBaseUrl: '', usesMockData: false),
        apiBaseService: mockApi,
      );
    });

    test(
      'loads the selected organisation roles from its roles route',
      () async {
        when(
          () => mockApi.get<Map<String, dynamic>>(
            path: '/organisations/org-1/roles',
          ),
        ).thenAnswer(
          (_) async => const ApiResponseModel<Map<String, dynamic>>(
            statusCode: 200,
            data: {
              'data': [
                {
                  'id': 'role-1',
                  'name': 'Manager',
                  'description': 'Runs the workspace',
                  'permissions': {
                    'can_create_channels': true,
                    'can_delete_org': false,
                  },
                },
              ],
            },
          ),
        );

        final roles = await datasource.getRolesAndPermissions(orgId: 'org-1');

        expect(roles.single.role, 'Manager');
        expect(roles.single.description, 'Runs the workspace');
        expect(roles.single.permissions, ['Create channels']);
      },
    );

    test(
      'returns no roles and sends no request without an organisation',
      () async {
        final roles = await datasource.getRolesAndPermissions();

        expect(roles, isEmpty);
        verifyZeroInteractions(mockApi);
      },
    );
  });
  group('UserProfileRemoteDataSourceImpl.updateAccount', () {
    test(
      'sends cleared optional fields to PATCH /profile as empty strings',
      () async {
        final mockApi = MockApiBaseService();
        final datasource = UserProfileRemoteDataSourceImpl(
          config: const AppConfig(apiBaseUrl: '', usesMockData: false),
          apiBaseService: mockApi,
        );
        when(
          () => mockApi.patch<Map<String, dynamic>>(
            path: any(named: 'path'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => const ApiResponseModel<Map<String, dynamic>>(
            statusCode: 200,
            data: {'data': <String, dynamic>{}},
          ),
        );

        const account = ProfileAccount(
          name: 'Odofin Moronke',
          email: '',
          timezone: '',
          title: '',
          phoneNumber: '',
          displayName: '',
          namePronunciation: '',
        );

        await datasource.updateAccount(account);

        final data =
            verify(
                  () => mockApi.patch<Map<String, dynamic>>(
                    path: '/profile',
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as FormData;
        expect(Map.fromEntries(data.fields), {
          'full_name': 'Odofin Moronke',
          'display_name': '',
          'phone': '',
          'title': '',
          'name_pronounciation': '',
        });
      },
    );
  });

  group('UserProfileRemoteDataSourceImpl.updateMember (Ziki #581)', () {
    late MockApiBaseService mockApi;
    late UserProfileRemoteDataSourceImpl datasource;

    setUp(() {
      mockApi = MockApiBaseService();
      datasource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(apiBaseUrl: '', usesMockData: false),
        apiBaseService: mockApi,
      );
      when(
        () => mockApi.patch<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': <String, dynamic>{}},
        ),
      );
    });

    test(
      'updates member role with PATCH /organisations/{org_id}/users/{user_id}/role',
      () async {
        const member = TeamMember(
          id: 'user-42',
          email: 'member@zedu.chat',
          role: 'Administrator',
          dateJoined: 'Nov 1, 2026',
          status: TeamMemberStatus.active,
        );

        await datasource.updateMember(
          member,
          orgId: 'org-99',
          roleId: 'role-admin-uuid',
        );

        verify(
          () => mockApi.patch<Map<String, dynamic>>(
            path: '/organisations/org-99/users/user-42/role',
            data: {'role_id': 'role-admin-uuid'},
          ),
        ).called(1);
      },
    );

    test(
      'never calls the non-existent /profile/organization/members route',
      () async {
        const member = TeamMember(
          id: 'user-42',
          email: 'member@zedu.chat',
          role: 'Administrator',
          dateJoined: 'Nov 1, 2026',
          status: TeamMemberStatus.active,
        );

        await datasource.updateMember(member, orgId: 'org-99');

        verifyNever(
          () => mockApi.patch<Map<String, dynamic>>(
            path: '/profile/organization/members/user-42',
            data: any(named: 'data'),
          ),
        );
      },
    );
  });

  group('UserProfileRemoteDataSourceImpl.removeMember (Ziki #581)', () {
    late MockApiBaseService mockApi;
    late UserProfileRemoteDataSourceImpl datasource;

    setUp(() {
      mockApi = MockApiBaseService();
      datasource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(apiBaseUrl: '', usesMockData: false),
        apiBaseService: mockApi,
      );
      when(
        () => mockApi.delete<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': <String, dynamic>{}},
        ),
      );
    });

    test(
      'removes member with DELETE /organisations/{org_id}/users/{user_id}',
      () async {
        await datasource.removeMember('user-42', orgId: 'org-99');

        verify(
          () => mockApi.delete<Map<String, dynamic>>(
            path: '/organisations/org-99/users/user-42',
          ),
        ).called(1);
      },
    );

    test(
      'never calls the non-existent /profile/organization/members route',
      () async {
        await datasource.removeMember('user-42', orgId: 'org-99');

        verifyNever(
          () => mockApi.delete<Map<String, dynamic>>(
            path: '/profile/organization/members/user-42',
          ),
        );
      },
    );
  });
}
