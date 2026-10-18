import 'dart:async';
import 'dart:io';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// How long Google sign-in waits for the browser to come back before giving up.
const googleRedirectTimeout = Duration(minutes: 3);

/// Waits for the first request to the loopback [server] (Google's redirect).
///
/// Returns null if nothing arrives within [timeout], e.g. because the user
/// closed the browser tab, so an abandoned sign-in doesn't wait forever.
/// Also returns null if [server] is closed while waiting.
Future<HttpRequest?> waitForLoopbackRedirect(
  HttpServer server, {
  Duration timeout = googleRedirectTimeout,
}) async {
  try {
    return await server.first.timeout(timeout);
  } on TimeoutException {
    return null;
  } on StateError {
    return null; // the server closed before a request arrived
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late AuthRepository _repository;
  late SecureStorageService _storage;
  late AuthInterceptor _interceptor;

  static const _tag = 'AuthNotifier';

  // The Google sign-in still waiting for the browser, if any. Clicking Google
  // again replaces it, so the new attempt can bind the loopback port.
  HttpServer? _googleServer;
  int _googleAttempt = 0;
  // Attempts take turns claiming the port, so two quick clicks can't both
  // try to bind it at once.
  Future<void> _googlePortClaim = Future.value();

  @override
  AuthState build() {
    _repository = ref.read(authRepositoryProvider);
    _storage = locator<SecureStorageService>();
    _interceptor = locator<AuthInterceptor>();

    _interceptor.onUnauthorized = () {
      AppLogger.w('Unauthorized — clearing session', tag: _tag);
      state = const AuthState(status: AuthStatus.unauthenticated);
    };
    _restoreSession();
    return const AuthState(status: AuthStatus.unknown);
  }

  Future<void> _restoreSession() async {
    AppLogger.d('Restoring session from storage', tag: _tag);
    final token = await _storage.getAccessToken();
    if (token == null) {
      AppLogger.i('No stored token — unauthenticated', tag: _tag);
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    final result = await _repository.getCurrentUser();
    switch (result) {
      case Success<User>():
        AppLogger.i('Session restored — ${result.value.email}', tag: _tag);
        state = AuthState(status: AuthStatus.authenticated, user: result.value);
      case Failure<User>():
        AppLogger.w('Session restore failed — clearing token', tag: _tag);
        await _storage.deleteAccessToken();
        state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({required String email, required String password}) async {
    AppLogger.d('Login attempt — $email', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.login(email: email, password: password);
    switch (result) {
      case Success<AuthSession>():
        AppLogger.i('Login succeeded — token persisted', tag: _tag);
        await _storage.saveAccessToken(result.value.accessToken);
        state = AuthState(
          status: AuthStatus.authenticated,
          user: result.value.user,
        );
      case Failure<AuthSession>():
        AppLogger.w('Login rejected — ${result.error.message}', tag: _tag);
        state = state.copyWith(
          isLoading: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> verifyMagicLink({required String token}) async {
    AppLogger.d('Magic link verification attempt', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.verifyMagicLink(token: token);
    switch (result) {
      case Success<AuthSession>():
        AppLogger.i(
          'Magic link verification succeeded — token persisted',
          tag: _tag,
        );
        await _storage.saveAccessToken(result.value.accessToken);
        state = AuthState(
          status: AuthStatus.authenticated,
          user: result.value.user,
        );
      case Failure<AuthSession>():
        AppLogger.w(
          'Magic link verification failed — ${result.error.message}',
          tag: _tag,
        );
        state = state.copyWith(
          isLoading: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<void> logout() async {
    AppLogger.i('Logout — clearing session', tag: _tag);
    await _storage.deleteAccessToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    AppLogger.d('Sign up attempt — $email', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.signUp(
      username: username,
      email: email,
      password: password,
    );
    switch (result) {
      case Success<void>():
        AppLogger.i('Sign up succeeded', tag: _tag);
        // Usually we login automatically after sign up or wait for verification
        await login(email: email, password: password);
      case Failure<void>():
        AppLogger.w('Sign up failed — ${result.error.message}', tag: _tag);
        state = state.copyWith(
          isLoading: false,
          error: result.error.friendlyMessage,
        );
    }
  }

  Future<bool> forgotPassword({required String email}) async {
    AppLogger.d('Forgot password attempt — $email', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.forgotPassword(email: email);
    switch (result) {
      case Success<void>():
        AppLogger.i('Forgot password email sent', tag: _tag);
        state = state.copyWith(isLoading: false);
        return true;
      case Failure<void>():
        AppLogger.w(
          'Forgot password failed — ${result.error.message}',
          tag: _tag,
        );
        state = state.copyWith(
          isLoading: false,
          error: result.error.friendlyMessage,
        );
        return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    AppLogger.d('Reset password attempt', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.resetPassword(
      email: email,
      token: token,
      newPassword: newPassword,
    );
    switch (result) {
      case Success<void>():
        AppLogger.i('Reset password succeeded', tag: _tag);
        state = state.copyWith(isLoading: false);
        return true;
      case Failure<void>():
        AppLogger.w(
          'Reset password failed — ${result.error.message}',
          tag: _tag,
        );
        state = state.copyWith(
          isLoading: false,
          error: result.error.friendlyMessage,
        );
        return false;
    }
  }

  Future<bool> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    AppLogger.d('Change password attempt', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.changePassword(
      email: email,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    switch (result) {
      case Success<void>():
        AppLogger.i('Change password succeeded', tag: _tag);
        state = state.copyWith(isLoading: false);
        return true;
      case Failure<void>():
        AppLogger.w(
          'Change password failed — ${result.error.message}',
          tag: _tag,
        );
        state = state.copyWith(
          isLoading: false,
          error: result.error.friendlyMessage,
        );
        return false;
    }
  }

  Future<String?> get accessToken => _storage.getAccessToken();

  Future<void> refreshCurrentUser() async {
    final result = await _repository.getCurrentUser();
    switch (result) {
      case Success<User>():
        state = state.copyWith(user: result.value);
      case Failure<User>():
        AppLogger.w(
          'Failed to refresh user — ${result.error.message}',
          tag: _tag,
        );
    }
  }

  Future<void> loginWithGoogle() async {
    AppLogger.d('Google Sign-In attempt', tag: _tag);
    final attempt = ++_googleAttempt;
    state = state.copyWith(isLoading: true, clearError: true);

    HttpServer? server;
    final earlierClaim = _googlePortClaim;
    final claim = Completer<void>();
    _googlePortClaim = claim.future;
    try {
      final config = locator<AppConfig>();
      const port = 8000; // Standard redirect port for desktop

      try {
        await earlierClaim;
        // An earlier attempt may still be waiting for the browser: drop it so
        // this one can use the port.
        await _googleServer?.close(force: true);

        // 1. Bind to localhost port to intercept the redirect
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
        _googleServer = server;
      } finally {
        claim.complete();
      }
      if (attempt != _googleAttempt) return; // replaced by a newer attempt
      AppLogger.d('Local loopback server listening on port $port', tag: _tag);

      final redirectUri = 'http://127.0.0.1:$port'; // Desktop Loopback URI
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': config.googleClientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': 'openid profile email',
        'access_type': 'offline',
        'prompt': 'consent',
        'application_type': 'desktop',
      });

      AppLogger.d('Launching Google Auth URL in browser', tag: _tag);
      await openInBrowser(authUrl);

      // 3. Wait for Google's redirect containing the authorization code
      final request = await waitForLoopbackRedirect(server);
      if (attempt != _googleAttempt) {
        // Replaced by a newer attempt. Still answer the browser so its tab
        // doesn't hang.
        if (request != null) {
          await _answerBrowser(
            request,
            title: 'Sign-in replaced',
            message:
                'A newer Google sign-in was started in Zedu. You can close '
                'this tab and finish signing in from the newest one.',
          );
        }
        return;
      }
      if (request == null) {
        AppLogger.w(
          'Google Sign-In timed out waiting for the browser',
          tag: _tag,
        );
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign-in timed out. Please try again.',
        );
        return;
      }
      final grantCode = request.uri.queryParameters['code'];

      // Return a clean page to the user in their browser
      if (grantCode == null) {
        await _answerBrowser(
          request,
          title: 'Sign-in cancelled',
          message:
              'Google sign-in was cancelled. You can close this tab and try '
              'again from Zedu.',
        );
      } else {
        await _answerBrowser(
          request,
          title: 'Sign In Successful!',
          message:
              'You have successfully authenticated with Zedu. You can now '
              'close this tab and return to the application.',
          success: true,
        );
      }

      await server.close();
      server = null;

      if (grantCode == null) {
        // e.g. error=access_denied: the user pressed Cancel on Google's page.
        AppLogger.w('Google Sign-In aborted or code not found', tag: _tag);
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign-in was cancelled.',
        );
        return;
      }

      AppLogger.i(
        'Raw authorization code retrieved successfully, sending to backend',
        tag: _tag,
      );

      final result = await _repository.signInWithGoogle(
        grantCode: grantCode,
        redirectUri: redirectUri,
      );
      // A newer attempt took over while the backend was answering: let it
      // decide the outcome instead of saving this login.
      if (attempt != _googleAttempt) return;
      switch (result) {
        case Success<AuthSession>():
          AppLogger.i('Google Sign-In succeeded — token persisted', tag: _tag);
          await _storage.saveAccessToken(result.value.accessToken);
          state = AuthState(
            status: AuthStatus.authenticated,
            user: result.value.user,
          );
        case Failure<AuthSession>():
          AppLogger.w(
            'Google Sign-In rejected — ${result.error.message}',
            tag: _tag,
          );
          state = state.copyWith(
            isLoading: false,
            error: result.error.friendlyMessage,
          );
      }
    } catch (e) {
      if (attempt != _googleAttempt) return; // replaced by a newer attempt
      AppLogger.e('Google Sign-In failed', tag: _tag, error: e);
      state = state.copyWith(isLoading: false, error: 'Google Sign-In failed');
    } finally {
      await server?.close();
      if (attempt == _googleAttempt) _googleServer = null;
    }
  }

  /// Opens Google's sign-in page in the user's browser. Tests replace this.
  @visibleForTesting
  Future<void> openInBrowser(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  /// Shows a short page in the browser tab that Google redirected to.
  Future<void> _answerBrowser(
    HttpRequest request, {
    required String title,
    required String message,
    bool success = false,
  }) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write('''
          <!DOCTYPE html>
          <html>
          <head>
            <title>$title</title>
            <style>
              body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; text-align: center; padding: 50px; background-color: #f9f9f9; }
              .card { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); display: inline-block; max-width: 400px; }
              h1 { color: ${success ? '#4CAF50' : '#666'}; margin-top: 0; }
              p { color: #666; font-size: 16px; }
            </style>
          </head>
          <body>
            <div class="card">
              <h1>$title</h1>
              <p>$message</p>
            </div>
          </body>
          </html>
        ''');
    await request.response.close();
  }

  // ── Status / Presence ────────────────────────────────────────────────────────

  /// Updates user's custom status and online presence.
  /// On success, the local [AuthState.user.status] is updated immediately
  /// so every widget watching [authNotifierProvider] reacts without a re-fetch.
  Future<bool> changeStatus({
    required String icon,
    required String text,
    required StatusTimeout timeout,
    required bool pauseNotifications,
    required bool online,
  }) async {
    AppLogger.d('changeStatus — "$text" online=$online', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.changeStatus(
      icon: icon,
      text: text,
      pauseNotifications: pauseNotifications,
      statusTimeout: timeout.apiValue,
      clearStatus: false,
      online: online,
    );

    switch (result) {
      case Success<void>():
        AppLogger.i('Status changed successfully', tag: _tag);
        final updatedStatus = UserStatus(
          emoji: icon.isEmpty ? null : icon,
          text: text.isEmpty ? null : text,
          expiresAt: _expiryFromTimeout(timeout),
          pauseNotifications: pauseNotifications,
          online: online,
        );
        state = state.copyWith(
          isLoading: false,
          user: state.user?._withStatus(updatedStatus),
        );
        return true;

      case Failure<void>():
        AppLogger.w(
          'Status change failed — ${result.error.message}',
          tag: _tag,
        );
        state = state.copyWith(
          isLoading: false,
          error: result.error.friendlyMessage,
        );
        return false;
    }
  }

  /// Clears the current custom status while keeping presence unchanged.
  Future<bool> clearStatus() async {
    AppLogger.d('clearStatus', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final currentOnline = state.user?.status.online ?? true;
    final result = await _repository.changeStatus(
      icon: '',
      text: '',
      pauseNotifications: false,
      statusTimeout: StatusTimeout.dontRemove.apiValue,
      clearStatus: true,
      online: currentOnline,
    );

    switch (result) {
      case Success<void>():
        state = state.copyWith(
          isLoading: false,
          user: state.user?._withStatus(UserStatus(online: currentOnline)),
        );
        return true;
      case Failure<void>():
        state = state.copyWith(
          isLoading: false,
          error: result.error.friendlyMessage,
        );
        return false;
    }
  }

  /// Toggles between Active (online=true) and Away (online=false).
  Future<void> toggleOnlineStatus() async {
    final currentUser = state.user;
    if (currentUser == null) return;

    final newOnline = !currentUser.status.online;
    AppLogger.d('toggleOnlineStatus → online=$newOnline', tag: _tag);

    final currentStatus = currentUser.status;
    final result = await _repository.changeStatus(
      icon: currentStatus.emoji ?? '',
      text: currentStatus.text ?? '',
      pauseNotifications: currentStatus.pauseNotifications,
      statusTimeout: StatusTimeout.dontRemove.apiValue,
      clearStatus: false,
      online: newOnline,
    );

    if (result is Success<void>) {
      state = state.copyWith(
        user: currentUser._withStatus(
          currentStatus.copyWith(online: newOnline),
        ),
      );
    }
  }

  DateTime? _expiryFromTimeout(StatusTimeout timeout) {
    final now = DateTime.now();
    return switch (timeout) {
      StatusTimeout.thirtyMinutes => now.add(const Duration(minutes: 30)),
      StatusTimeout.oneHour => now.add(const Duration(hours: 1)),
      StatusTimeout.today => DateTime(now.year, now.month, now.day, 23, 59),
      StatusTimeout.thisWeek => now.add(Duration(days: 7 - now.weekday)),
      StatusTimeout.dontRemove => null,
    };
  }
}

// Private extension to create a new User with a swapped status field.
extension _UserStatusSwap on User {
  User _withStatus(UserStatus newStatus) => User(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    phone: phone,
    username: username,
    isVerified: isVerified,
    isOnboarded: isOnboarded,
    createdAt: createdAt,
    currentOrg: currentOrg,
    currentOrganisationSlug: currentOrganisationSlug,
    avatarUrl: avatarUrl,
    defaultAvatarUrl: defaultAvatarUrl,
    creditBalance: creditBalance,
    subscriptionPlanId: subscriptionPlanId,
    aiCreditsPurchasable: aiCreditsPurchasable,
    status: newStatus,
  );
}
