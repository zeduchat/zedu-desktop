import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

// data/repositories/auth_repository_impl.dart

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required AuthRemoteDataSource remote})
    : _remote = remote;

  final AuthRemoteDataSource _remote;

  static const _tag = 'AuthRepository';

  static const _invalidCredentialsMessage =
      'Invalid email or password. Please check your credentials and try again.';

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _remote.login(email: email, password: password);

      AppLogger.i('Login successful — ${response.user.email}', tag: _tag);
      return Success(
        AuthSession(
          user: response.user.toEntity(),
          accessToken: response.accessToken,
          accessTokenExpiresIn: response.accessTokenExpiresIn,
        ),
      );
    } on ApiFailure catch (failure) {
      AppLogger.w('Login failed — ${failure.message}', tag: _tag);
      return Failure(_hideCredentialDetail(failure));
    } catch (error) {
      AppLogger.e('Unexpected login error', tag: _tag, error: error);
      return Failure(ApiFailure.unknown(error));
    }
  }

  /// A rejected credential check must not say which half was wrong, or the
  /// login form becomes a tool for confirming which emails have accounts.
  /// 400 and 401 are the wrong-password answers and 404 is this backend's
  /// "no account for that email" signal, as magic_link_request_view.dart
  /// documents. Rate limits and server faults keep their own copy, because
  /// that copy tells the user what to do next. The client kind is the one
  /// whose message is shown verbatim, so the generic text has to carry it.
  static ApiFailure _hideCredentialDetail(ApiFailure failure) {
    final code = failure.statusCode;
    if (code != 400 && code != 401 && code != 404) return failure;
    return ApiFailure(
      message: _invalidCredentialsMessage,
      statusCode: code,
      path: failure.path,
      kind: ApiFailureKind.client,
    );
  }

  @override
  Future<Result<User>> getCurrentUser() async {
    try {
      final user = await _remote.me();
      AppLogger.i('Current user fetched — ${user.email}', tag: _tag);
      return Success(user.toEntity());
    } on ApiFailure catch (failure) {
      AppLogger.w(
        'Failed to fetch current user — ${failure.message}',
        tag: _tag,
      );
      return Failure(failure);
    } catch (error) {
      AppLogger.e(
        'Unexpected error fetching current user',
        tag: _tag,
        error: error,
      );
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<void>> sendMagicLink({required String email}) async {
    try {
      await _remote.sendMagicLink(email: email);
      AppLogger.i('Magic link request sent — $email', tag: _tag);
      return const Success(null);
    } on ApiFailure catch (failure) {
      AppLogger.w('Magic link request failed — ${failure.message}', tag: _tag);
      return Failure(failure);
    } catch (error) {
      AppLogger.e(
        'Unexpected magic link request error',
        tag: _tag,
        error: error,
      );
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<void>> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      await _remote.signUp(
        username: username,
        email: email,
        password: password,
      );
      return const Success(null);
    } on ApiFailure catch (failure) {
      return Failure(failure);
    } catch (error) {
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<AuthSession>> verifyMagicLink({required String token}) async {
    try {
      final response = await _remote.verifyMagicLink(token: token);
      AppLogger.i(
        'Magic link verification successful — ${response.user.email}',
        tag: _tag,
      );
      return Success(
        AuthSession(
          user: response.user.toEntity(),
          accessToken: response.accessToken,
          accessTokenExpiresIn: response.accessTokenExpiresIn,
        ),
      );
    } on ApiFailure catch (failure) {
      AppLogger.w(
        'Magic link verification failed — ${failure.message}',
        tag: _tag,
      );
      return Failure(failure);
    } catch (error) {
      AppLogger.e(
        'Unexpected magic link verification error',
        tag: _tag,
        error: error,
      );
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<void>> forgotPassword({required String email}) async {
    try {
      await _remote.forgotPassword(email: email);
      return const Success(null);
    } on ApiFailure catch (failure) {
      return Failure(failure);
    } catch (error) {
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<AuthSession>> signInWithGoogle({
    required String grantCode,
    String? redirectUri,
  }) async {
    try {
      final response = await _remote.signInWithGoogle(
        grantCode: grantCode,
        redirectUri: redirectUri,
      );
      AppLogger.i(
        'Google sign-in successful — ${response.user.email}',
        tag: _tag,
      );
      return Success(
        AuthSession(
          user: response.user.toEntity(),
          accessToken: response.accessToken,
          accessTokenExpiresIn: response.accessTokenExpiresIn,
        ),
      );
    } on ApiFailure catch (failure) {
      AppLogger.w('Google sign-in failed — ${failure.message}', tag: _tag);
      return Failure(failure);
    } catch (error) {
      AppLogger.e('Unexpected Google sign-in error', tag: _tag, error: error);
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<void>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await _remote.resetPassword(
        email: email,
        token: token,
        newPassword: newPassword,
      );
      return const Success(null);
    } on ApiFailure catch (failure) {
      return Failure(failure);
    } catch (error) {
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<void>> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _remote.changePassword(
        email: email,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return const Success(null);
    } on ApiFailure catch (failure) {
      return Failure(failure);
    } catch (error) {
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<void>> changeStatus({
    required String icon,
    required String text,
    required bool pauseNotifications,
    required String statusTimeout,
    required bool clearStatus,
    required bool online,
  }) async {
    try {
      await _remote.changeStatus(
        icon: icon,
        text: text,
        pauseNotifications: pauseNotifications,
        statusTimeout: statusTimeout,
        clearStatus: clearStatus,
        online: online,
      );
      AppLogger.i('Status updated successfully', tag: _tag);
      return const Success(null);
    } on ApiFailure catch (failure) {
      AppLogger.w('Status update failed — ${failure.message}', tag: _tag);
      return Failure(failure);
    } catch (error) {
      AppLogger.e('Unexpected status update error', tag: _tag, error: error);
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<void>> setPresence({required bool online}) async {
    try {
      await _remote.setPresence(online: online);
      AppLogger.i('Presence updated — online=$online', tag: _tag);
      return const Success(null);
    } on ApiFailure catch (failure) {
      AppLogger.w('Presence update failed — ${failure.message}', tag: _tag);
      return Failure(failure);
    } catch (error) {
      AppLogger.e('Unexpected presence update error', tag: _tag, error: error);
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _remote.logout();
      AppLogger.i('Backend session revoked', tag: _tag);
      return const Success(null);
    } on ApiFailure catch (failure) {
      AppLogger.w('Backend logout failed — ${failure.message}', tag: _tag);
      return Failure(failure);
    } catch (error) {
      AppLogger.e('Unexpected logout error', tag: _tag, error: error);
      return Failure(ApiFailure.unknown(error));
    }
  }
}
