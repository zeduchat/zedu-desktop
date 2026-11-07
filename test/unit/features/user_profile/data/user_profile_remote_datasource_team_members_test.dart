import '../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('UserProfileRemoteDataSourceImpl.getTeamMembers', () {
    const orgId = '11111111-2222-3333-4444-555555555555';
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
    });

    for (final invalid in <String?>[null, '', 'short-id']) {
      test('refuses the org id "$invalid" without calling the API', () async {
        await expectLater(
          dataSource.getTeamMembers(orgId: invalid),
          throwsA(
            isA<ApiFailure>().having(
              (failure) => failure.kind,
              'kind',
              ApiFailureKind.client,
            ),
          ),
        );
        verifyNever(
          () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
        );
      });
    }

    test('loads the members of the requested organisation', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenAnswer(
        (_) async => const ApiResponseModel(
          data: <String, dynamic>{
            'data': [
              {'id': 'u-1', 'email': 'ada@example.com', 'name': 'Ada'},
            ],
          },
          statusCode: 200,
        ),
      );

      final members = await dataSource.getTeamMembers(orgId: orgId);

      expect(members.single.name, 'Ada');
      verify(
        () =>
            api.get<Map<String, dynamic>>(path: '/organisations/$orgId/users'),
      ).called(1);
    });

    test('passes API failures on instead of returning no members', () async {
      const failure = ApiFailure(
        message: 'unavailable',
        kind: ApiFailureKind.server,
      );
      when(
        () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenThrow(failure);

      await expectLater(
        dataSource.getTeamMembers(orgId: orgId),
        throwsA(same(failure)),
      );
    });
  });
}
