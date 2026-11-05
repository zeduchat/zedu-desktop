import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

// domain/repositories/auth_repository.dart

abstract interface class AuthRepository {
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  });
  Future<Result<User>> getCurrentUser();
  Future<Result<void>> sendMagicLink({required String email});
  Future<Result<AuthSession>> verifyMagicLink({required String token});
  Future<Result<AuthSession>> signInWithGoogle({
    required String grantCode,
    String? redirectUri,
  });
  Future<Result<void>> signUp({
    required String username,
    required String email,
    required String password,
  });
  Future<Result<void>> forgotPassword({required String email});
  Future<Result<void>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  });
  Future<Result<void>> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  });
  Future<Result<void>> changeStatus({
    required String icon,
    required String text,
    required bool pauseNotifications,
    required String statusTimeout,
    required bool clearStatus,
    required bool online,
  });
  Future<Result<void>> setPresence({required bool online});
}
