import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late AppConfig config;
  late CreditsRemoteDataSourceImpl datasource;

  setUp(() {
    api = MockApiBaseService();
    config = const AppConfig(
      apiBaseUrl: 'https://api.staging.zedu.chat/api/v1/',
      usesMockData: false,
    );
    datasource = CreditsRemoteDataSourceImpl(
      config: config,
      apiBaseService: api,
    );
  });

  group('CreditsRemoteDataSourceImpl.purchaseCredits', () {
    test(
      'sends POST /credits/purchase with Referer header, package_id and email',
      () async {
        when(
          () => api.post<Map<String, dynamic>>(
            path: '/credits/purchase',
            headers: {'Referer': 'https://api.staging.zedu.chat/api/v1/'},
            data: {
              'package_id': 'pkg-ai-starter',
              'plan_id': 'pkg-ai-starter',
              'email': 'contributor@zedu.chat',
            },
          ),
        ).thenAnswer(
          (_) async => const ApiResponseModel<Map<String, dynamic>>(
            statusCode: 200,
            data: {
              'status': 'success',
              'data': {
                'checkout_session_id': 'cs_test_session_123',
                'checkout_session_url':
                    'https://checkout.stripe.com/c/pay/cs_test_session_123',
              },
            },
          ),
        );

        final checkout = await datasource.purchaseCredits(
          packageId: 'pkg-ai-starter',
          email: 'contributor@zedu.chat',
        );

        expect(checkout.checkoutSessionId, 'cs_test_session_123');
        expect(
          checkout.checkoutSessionUrl,
          'https://checkout.stripe.com/c/pay/cs_test_session_123',
        );
        verify(
          () => api.post<Map<String, dynamic>>(
            path: '/credits/purchase',
            headers: {'Referer': 'https://api.staging.zedu.chat/api/v1/'},
            data: {
              'package_id': 'pkg-ai-starter',
              'plan_id': 'pkg-ai-starter',
              'email': 'contributor@zedu.chat',
            },
          ),
        ).called(1);
      },
    );

    test('falls back to planId when packageId is not supplied', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/credits/purchase',
          headers: {'Referer': 'https://api.staging.zedu.chat/api/v1/'},
          data: {
            'package_id': 'pkg-legacy-plan',
            'plan_id': 'pkg-legacy-plan',
            'email': 'test@example.com',
          },
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'status': 'success',
            'data': {
              'checkout_session_id': 'cs_test_plan_fallback',
              'checkout_session_url': 'https://checkout.stripe.com/pay',
            },
          },
        ),
      );

      final checkout = await datasource.purchaseCredits(
        planId: 'pkg-legacy-plan',
        email: 'test@example.com',
      );

      expect(checkout.checkoutSessionId, 'cs_test_plan_fallback');
      verify(
        () => api.post<Map<String, dynamic>>(
          path: '/credits/purchase',
          headers: {'Referer': 'https://api.staging.zedu.chat/api/v1/'},
          data: {
            'package_id': 'pkg-legacy-plan',
            'plan_id': 'pkg-legacy-plan',
            'email': 'test@example.com',
          },
        ),
      ).called(1);
    });

    test('throws ApiFailure when response data is malformed', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/credits/purchase',
          headers: any(named: 'headers'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'status': 'success', 'data': null},
        ),
      );

      expect(
        () => datasource.purchaseCredits(
          packageId: 'pkg-malformed',
          email: 'test@example.com',
        ),
        throwsA(isA<ApiFailure>()),
      );
    });

    test(
      'returns mock checkout model without network call when usesMockData is true',
      () async {
        final mockDatasource = CreditsRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.staging.zedu.chat/api/v1/',
            usesMockData: true,
          ),
          apiBaseService: api,
        );

        final checkout = await mockDatasource.purchaseCredits(
          packageId: 'mock-plan-1',
          email: 'mock@example.com',
        );

        expect(checkout.checkoutSessionId, contains('cs_test_mock_'));
        expect(checkout.checkoutSessionUrl, contains('session_id='));
        verifyZeroInteractions(api);
      },
    );
  });

  group('CreditsRepositoryImpl.purchaseCredits', () {
    test('delegates to remote data source and returns Success', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/credits/purchase',
          headers: any(named: 'headers'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'status': 'success',
            'data': {
              'checkout_session_id': 'cs_session_repo_test',
              'checkout_session_url': 'https://checkout.stripe.com/repo',
            },
          },
        ),
      );

      final repository = CreditsRepositoryImpl(remote: datasource);
      final result = await repository.purchaseCredits(
        packageId: 'pkg-repo',
        email: 'repo@example.com',
      );

      expect(result, isA<Success<CreditCheckoutSession>>());
      final session = (result as Success<CreditCheckoutSession>).value;
      expect(session.checkoutSessionId, 'cs_session_repo_test');
      expect(session.checkoutSessionUrl, 'https://checkout.stripe.com/repo');
    });

    test('returns Failure when remote call throws ApiFailure', () async {
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/credits/purchase',
          headers: any(named: 'headers'),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        const ApiFailure(
          message: 'Validation failed',
          statusCode: 422,
          kind: ApiFailureKind.client,
        ),
      );

      final repository = CreditsRepositoryImpl(remote: datasource);
      final result = await repository.purchaseCredits(
        packageId: 'pkg-fail',
        email: 'fail@example.com',
      );

      expect(result, isA<Failure<CreditCheckoutSession>>());
      final failure = (result as Failure<CreditCheckoutSession>).error;
      expect(failure.message, 'Validation failed');
      expect(failure.statusCode, 422);
    });
  });
}
