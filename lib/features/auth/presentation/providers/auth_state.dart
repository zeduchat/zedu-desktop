import 'package:zedu/features/features.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.isLoading = false,
    this.sessionExpired = false,
    this.sessionRestoreFailed = false,
  });

  final AuthStatus status;
  final User? user;
  final String? error;
  final bool isLoading;

  /// True when a 401 ended a signed-in session (not a logout).
  final bool sessionExpired;

  /// The saved session could not be checked because the server could not be
  /// reached. The token is kept, so trying again can still restore it.
  final bool sessionRestoreFailed;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? isLoading,
    bool? sessionExpired,
    bool? sessionRestoreFailed,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
      sessionExpired: sessionExpired ?? this.sessionExpired,
      sessionRestoreFailed: sessionRestoreFailed ?? this.sessionRestoreFailed,
    );
  }
}
