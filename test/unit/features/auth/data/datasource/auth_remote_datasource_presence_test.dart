import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('AuthRemoteDataSourceImpl.setPresence transport contract', () {
    late MockApiBaseService api;
    late AuthRemoteDataSourceImpl datasource;

    setUp(() {
      api = MockApiBaseService();
      datasource = AuthRemoteDataSourceImpl(
        config: const AppConfig(
          apiBaseUrl: 'https://api.test.example/api/v1/',
          usesMockData: false,
        ),
        apiBaseService: api,
      );
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

    test('POSTs only {"online": bool} to profile/presence (away)', () async {
      await datasource.setPresence(online: false);

      verify(
        () => api.post<dynamic>(
          path: 'profile/presence',
          data: {'online': false},
        ),
      ).called(1);
    });

    test('POSTs only {"online": bool} to profile/presence (active)', () async {
      await datasource.setPresence(online: true);

      verify(
        () =>
            api.post<dynamic>(path: 'profile/presence', data: {'online': true}),
      ).called(1);
    });

    test(
      'never sends custom-status fields (icon/text/timeout/notifications)',
      () async {
        await datasource.setPresence(online: false);

        final captured = verify(
          () => api.post<dynamic>(
            path: captureAny(named: 'path'),
            data: captureAny(named: 'data'),
          ),
        ).captured;

        expect(captured[0], 'profile/presence');
        final body = captured[1] as Map<String, dynamic>;
        expect(body.keys, unorderedEquals(['online']));
      },
    );

    test('rethrows ApiFailure untouched', () async {
      final failure = ApiFailure(
        message: 'boom',
        kind: ApiFailureKind.server,
        statusCode: 500,
      );
      when(
        () => api.post<dynamic>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenThrow(failure);

      await expectLater(
        datasource.setPresence(online: true),
        throwsA(same(failure)),
      );
    });
  });
}
