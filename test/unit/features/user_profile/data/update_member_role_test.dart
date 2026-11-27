import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

const _member = TeamMember(
  id: 'user-1',
  email: 'owner@zedu.test',
  role: 'Manager',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
  name: 'Owner',
);

void main() {
  group('UserProfileRemoteDataSourceImpl.updateMember', () {
    test('PATCHes the organisation role route with the role id', () async {
      final config = AppConfig(
        apiBaseUrl: 'https://api.example.com/api/v1/',
        usesMockData: false,
      );
      final dio = Dio();
      RequestOptions? captured;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            // zedu-be answers with no member data.
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {'status': 'success', 'data': null},
              ),
            );
          },
        ),
      );
      final dataSource = UserProfileRemoteDataSourceImpl(
        config: config,
        apiBaseService: ApiBaseService(config: config, dio: dio),
      );

      final updated = await dataSource.updateMember(
        _member,
        roleId: 'role-manager',
        orgId: 'org-1',
      );

      expect(captured!.method, 'PATCH');
      expect(captured!.path, endsWith('organisations/org-1/users/user-1/role'));
      expect(captured!.data, {'role_id': 'role-manager'});
      expect(updated.id, 'user-1');
      expect(updated.role, 'Manager');
      expect(updated.email, 'owner@zedu.test');
    });
  });
}
