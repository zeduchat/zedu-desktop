import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late CreditsRemoteDataSourceImpl datasource;

  CreditsRemoteDataSourceImpl createDatasource() => CreditsRemoteDataSourceImpl(
    config: const AppConfig(
      apiBaseUrl: 'https://example.invalid',
      usesMockData: true,
    ),
    apiBaseService: api,
  );

  setUp(() {
    api = MockApiBaseService();
    datasource = createDatasource();
  });

  test(
    'mock verification updates readable usage without an API request',
    () async {
      await datasource.verifyPayment(sessionId: 'mock-session');

      final usage = await datasource.getUsage('org');
      expect(usage.balance, 1010);
      expect(usage.totalPurchased, 1010);
      expect(usage.totalConsumed, 0);
      verifyZeroInteractions(api);
    },
  );

  test('subsequent mock verifications update existing usage', () async {
    await datasource.verifyPayment(sessionId: 'first-session');
    await datasource.verifyPayment(sessionId: 'second-session');

    final usage = await datasource.getUsage('org');
    expect(usage.balance, 2010);
    expect(usage.totalPurchased, 2010);
    expect(usage.totalConsumed, 0);
  });

  test('mock usage is isolated between datasource instances', () async {
    final other = createDatasource();
    await datasource.verifyPayment(sessionId: 'mock-session');

    final usage = await other.getUsage('org');
    expect(usage.balance, 10);
    expect(usage.totalPurchased, 10);
    expect(usage.totalConsumed, 0);
  });

  test(
    'live verification sends the session to the existing endpoint',
    () async {
      final live = CreditsRemoteDataSourceImpl(
        config: const AppConfig(
          apiBaseUrl: 'https://example.invalid',
          usesMockData: false,
        ),
        apiBaseService: api,
      );
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/credits/verify-payment',
          data: {'session_id': 'live-session'},
        ),
      ).thenAnswer(
        (_) async =>
            const ApiResponseModel(data: <String, dynamic>{}, statusCode: 200),
      );

      await live.verifyPayment(sessionId: 'live-session');

      verify(
        () => api.post<Map<String, dynamic>>(
          path: '/credits/verify-payment',
          data: {'session_id': 'live-session'},
        ),
      ).called(1);
      verifyNoMoreInteractions(api);
    },
  );
}
