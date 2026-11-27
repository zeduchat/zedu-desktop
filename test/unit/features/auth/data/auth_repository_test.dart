import '../../../../helpers/helpers.dart';
import 'package:zedu/core/mock/mock.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

const _genericLoginError =
    'Invalid email or password. Please check your credentials and try again.';

void main() {
  group('AuthRepositoryImpl', () {
    late MockAuthRemoteDataSource mockDatasource;
    late AuthRepositoryImpl repository;

    setUp(() {
      mockDatasource = MockAuthRemoteDataSource();
      repository = AuthRepositoryImpl(remote: mockDatasource);
    });

    group('login', () {
      test('returns Success<AuthSession> when datasource succeeds', () async {
        final mockResponse = LoginResponseModel.fromJson(mockLoginResponse);

        when(
          () => mockDatasource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await repository.login(
          email: 'test@example.com',
          password: 'Password123',
        );

        expect(result, isA<Success<AuthSession>>());
        final session = (result as Success<AuthSession>).value;
        expect(session.accessToken, mockResponse.accessToken);
        expect(session.user.email, mockResponse.user.email);
      });

      test('returns Failure when datasource throws ApiFailure', () async {
        when(
          () => mockDatasource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiFailure(
            message: 'Invalid credentials',
            kind: ApiFailureKind.client,
          ),
        );

        final result = await repository.login(
          email: 'test@example.com',
          password: 'wrongpass',
        );

        expect(result, isA<Failure<AuthSession>>());
      });

      test('returns Failure for unexpected errors', () async {
        when(
          () => mockDatasource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception('unexpected error'));

        final result = await repository.login(
          email: 'test@example.com',
          password: 'password',
        );

        expect(result, isA<Failure<AuthSession>>());
      });

      test('shows one message for a 400 login failure', () async {
        when(
          () => mockDatasource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiFailure(
            message: 'Invalid email and password supplied',
            statusCode: 400,
            path: '/auth/login',
            kind: ApiFailureKind.client,
          ),
        );

        final result = await repository.login(
          email: 'test@example.com',
          password: 'wrongpass',
        );

        final error = (result as Failure<AuthSession>).error;
        expect(error.friendlyMessage, _genericLoginError);
        expect(error.statusCode, 400);
        expect(error.path, '/auth/login');
      });

      test('shows one message for a 401 login failure', () async {
        when(
          () => mockDatasource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiFailure(
            message: 'Password does not match',
            statusCode: 401,
            path: '/auth/login',
            kind: ApiFailureKind.unauthorized,
          ),
        );

        final result = await repository.login(
          email: 'test@example.com',
          password: 'wrongpass',
        );

        final error = (result as Failure<AuthSession>).error;
        expect(error.friendlyMessage, _genericLoginError);
        expect(error.kind, ApiFailureKind.client);
      });

      test('shows one message for a 404 login failure', () async {
        when(
          () => mockDatasource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiFailure(
            message: 'No account found for this email',
            statusCode: 404,
            path: '/auth/login',
            kind: ApiFailureKind.notFound,
          ),
        );

        final result = await repository.login(
          email: 'nobody@example.com',
          password: 'whatever123',
        );

        final error = (result as Failure<AuthSession>).error;
        expect(error.friendlyMessage, _genericLoginError);
        expect(error.message, isNot(contains('No account')));
      });

      test('keeps the rate limit message on 429', () async {
        const rateLimitCopy = 'Too many attempts. Please try again later.';
        when(
          () => mockDatasource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiFailure(
            message: rateLimitCopy,
            statusCode: 429,
            path: '/auth/login',
            kind: ApiFailureKind.client,
          ),
        );

        final result = await repository.login(
          email: 'test@example.com',
          password: 'wrongpass',
        );

        final error = (result as Failure<AuthSession>).error;
        expect(error.message, rateLimitCopy);
        expect(error.friendlyMessage, rateLimitCopy);
      });

      test('leaves a server fault message alone', () async {
        when(
          () => mockDatasource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiFailure(
            message: 'Upstream auth service is down',
            statusCode: 503,
            path: '/auth/login',
            kind: ApiFailureKind.server,
          ),
        );

        final result = await repository.login(
          email: 'test@example.com',
          password: 'Password123',
        );

        final error = (result as Failure<AuthSession>).error;
        expect(error.message, 'Upstream auth service is down');
        expect(error.kind, ApiFailureKind.server);
      });
    });

    group('getCurrentUser', () {
      test('returns Success<User> when datasource succeeds', () async {
        final mockUser = ProfileModel.fromJson(
          mockLoginResponse['user'] as Map<String, dynamic>,
        );

        when(() => mockDatasource.me()).thenAnswer((_) async => mockUser);

        final result = await repository.getCurrentUser();

        expect(result, isA<Success<User>>());
        final user = (result as Success<User>).value;
        expect(user.email, mockUser.email);
      });

      test('keeps the status from /profile on the restored user', () async {
        final profile = ProfileModel.fromJson({
          ...mockLoginResponse['user'] as Map<String, dynamic>,
          'icon': '🌴',
          'text': 'Vacationing',
          'status_timeout': 'dont-clear',
          'online': false,
        });
        when(() => mockDatasource.me()).thenAnswer((_) async => profile);

        final result = await repository.getCurrentUser();

        final status = (result as Success<User>).value.status;
        expect(status.emoji, '🌴');
        expect(status.text, 'Vacationing');
        expect(status.expiresAt, isNull);
        expect(status.online, isFalse);
        expect(status.hasCustomStatus, isTrue);
      });

      test('returns Failure when datasource throws ApiFailure', () async {
        when(() => mockDatasource.me()).thenThrow(
          const ApiFailure(
            message: 'Unauthorized',
            kind: ApiFailureKind.unauthorized,
          ),
        );

        final result = await repository.getCurrentUser();

        expect(result, isA<Failure<User>>());
      });

      test('returns Failure for unexpected errors', () async {
        when(() => mockDatasource.me()).thenThrow(Exception('unexpected'));

        final result = await repository.getCurrentUser();

        expect(result, isA<Failure<User>>());
      });
    });
  });
}
