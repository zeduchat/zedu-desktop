import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

AuthRemoteDataSourceImpl _datasource(
  ApiBaseService api, {
  bool usesMockData = false,
}) => AuthRemoteDataSourceImpl(
  config: AppConfig(
    apiBaseUrl: 'https://api.test.example/api/v1/',
    usesMockData: usesMockData,
  ),
  apiBaseService: api,
);

void main() {
  group('AuthRemoteDataSourceImpl.logout', () {
    late MockApiBaseService api;

    setUp(() {
      api = MockApiBaseService();
      when(
        () => api.post<dynamic>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async =>
            const ApiResponseModel<dynamic>(data: null, statusCode: 200),
      );
    });

    test('POSTs to /auth/logout without a body', () async {
      await _datasource(api).logout();

      verify(() => api.post<dynamic>(path: '/auth/logout')).called(1);
    });

    test('rethrows ApiFailure untouched', () async {
      const failure = ApiFailure(
        message: 'unauthorized',
        kind: ApiFailureKind.unauthorized,
        statusCode: 401,
      );
      when(
        () => api.post<dynamic>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenThrow(failure);

      await expectLater(_datasource(api).logout(), throwsA(same(failure)));
    });

    test('sends nothing when using mock data', () async {
      await _datasource(api, usesMockData: true).logout();

      verifyNever(
        () => api.post<dynamic>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      );
    });
  });
}
