import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  group('AuthRepositoryImpl.logout', () {
    late MockAuthRemoteDataSource remote;
    late AuthRepositoryImpl repository;

    setUp(() {
      remote = MockAuthRemoteDataSource();
      repository = AuthRepositoryImpl(remote: remote);
    });

    test('maps a successful backend logout to Success', () async {
      when(() => remote.logout()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, isA<Success<void>>());
      verify(() => remote.logout()).called(1);
    });

    test('maps an ApiFailure to Failure without throwing', () async {
      const failure = ApiFailure(
        message: 'No internet connection',
        kind: ApiFailureKind.network,
      );
      when(() => remote.logout()).thenThrow(failure);

      final result = await repository.logout();

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error, same(failure));
    });

    test('maps an unexpected error to a Failure', () async {
      when(() => remote.logout()).thenThrow(StateError('socket closed'));

      final result = await repository.logout();

      expect(result, isA<Failure<void>>());
    });
  });
}
