import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  group('AuthRepositoryImpl.setPresence', () {
    late MockAuthRemoteDataSource remote;
    late AuthRepositoryImpl repository;

    setUp(() {
      remote = MockAuthRemoteDataSource();
      repository = AuthRepositoryImpl(remote: remote);
    });

    test('maps a successful presence update to Success', () async {
      when(
        () => remote.setPresence(online: any(named: 'online')),
      ).thenAnswer((_) async {});

      final result = await repository.setPresence(online: false);

      expect(result, isA<Success<void>>());
      verify(() => remote.setPresence(online: false)).called(1);
    });

    test('maps an ApiFailure to Failure without throwing', () async {
      const failure = ApiFailure(
        message: 'Failed to update user presence',
        kind: ApiFailureKind.client,
        statusCode: 400,
      );
      when(
        () => remote.setPresence(online: any(named: 'online')),
      ).thenThrow(failure);

      final result = await repository.setPresence(online: true);

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error, same(failure));
    });

    test('maps an unexpected error to a Failure', () async {
      when(
        () => remote.setPresence(online: any(named: 'online')),
      ).thenThrow(StateError('socket closed'));

      final result = await repository.setPresence(online: true);

      expect(result, isA<Failure<void>>());
    });
  });
}
