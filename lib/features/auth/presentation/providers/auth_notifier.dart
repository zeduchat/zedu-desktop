import 'dart:async';
import 'dart:io';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class AuthNotifier extends Notifier<AuthState> {
  late AuthRepository _repository;
  late SecureStorageService _storage;
  late AuthInterceptor _interceptor;

  /// How long [loginWithGoogle] waits for the browser redirect before giving
  /// up and clearing the loading state.
  Duration googleSignInWait = const Duration(minutes: 5);

  /// Guards against overlapping presence-toggle requests (rapid clicks,
  /// reopening the menu while a request is pending).
  bool _presenceToggleInFlight = false;

  /// Bumped on every session boundary (login, logout, unauthorized) so
  /// responses arriving after the boundary are discarded instead of leaking
  /// into the new session.
  int _sessionGeneration = 0;

  /// Monotonic sequence for custom-status mutations; a completed mutation
  /// only applies locally while no newer mutation has started.
  int _statusMutationSeq = 0;

  /// Serializes every repository call that carries an `online` flag. The
  /// backend's change-status endpoint writes the online flag unconditionally,
  /// so overlapping writes could reach it out of order and a stale one would
  /// silently undo a newer confirmed presence change. Chaining the requests
  /// (each send waits for the previous response) gives the backend one
  /// deterministic order: the last write it receives is always the client's
  /// latest intent.
  Future<void> _onlineWriteTail = Future<void>.value();

  /// The presence value the backend last confirmed for this session and identity context.
  /// Queued writes capture their `online` payload from this at send time, so an
  /// operation that waited in the queue carries the presence that is current
  /// when it reaches the server, not the one from when it was requested.
  bool? _confirmedOnline;
  int? _confirmedOnlineSessionGeneration;
  String? _confirmedOnlineUserId;
  String? _confirmedOnlineOrgId;

  _ConfirmedCustomStatus? _confirmedCustomStatus;

  /// Counts user-state mutations (presence and status writes) scoped to each
  /// session/identity context. A profile refresh that overlaps one — a mutation
  /// was in flight when the refresh started, or one started while the refresh was
  /// in flight in the same context — merges fresh profile fields with the locally
  /// newer status instead of replacing it with the older snapshot.
  final Map<_MutationContext, int> _mutationsStarted = {};
  final Map<_MutationContext, int> _mutationsCompleted = {};

  int _getMutationsStarted(_MutationContext ctx) => _mutationsStarted[ctx] ?? 0;
  int _getMutationsCompleted(_MutationContext ctx) =>
      _mutationsCompleted[ctx] ?? 0;

  void _recordMutationStarted(_MutationContext ctx) {
    _mutationsStarted[ctx] = _getMutationsStarted(ctx) + 1;
  }

  void _recordMutationCompleted(_MutationContext ctx) {
    _mutationsCompleted[ctx] = _getMutationsCompleted(ctx) + 1;
  }

  /// Clear a discarded custom-status mutation's loading flag only if it still
  /// belongs to the current authenticated user and is the latest status write.
  /// Never alter state belonging to a newer mutation or session.
  void _resetDiscardedStatusLoading({
    required int sessionGeneration,
    required int mutationSeq,
    required String userId,
  }) {
    if (!_disposed &&
        _sessionGeneration == sessionGeneration &&
        _statusMutationSeq == mutationSeq &&
        state.status == AuthStatus.authenticated &&
        state.user?.id == userId) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _setConfirmedOnline({
    required bool online,
    required int sessionGeneration,
    required String? userId,
    required String? orgId,
  }) {
    _confirmedOnline = online;
    _confirmedOnlineSessionGeneration = sessionGeneration;
    _confirmedOnlineUserId = userId;
    _confirmedOnlineOrgId = orgId;
  }

  void _clearConfirmedOnline() {
    _confirmedOnline = null;
    _confirmedOnlineSessionGeneration = null;
    _confirmedOnlineUserId = null;
    _confirmedOnlineOrgId = null;
  }

  bool _disposed = false;

  static const _tag = 'AuthNotifier';

  /// Shown once when a 401 ends a signed-in session.
  static const sessionExpiredMessage =
      'Your session has expired. Please sign in again.';

  /// Shown when an email+password login attempt is rejected. One generic
  /// message that does not reveal which credential was wrong and does not
  /// claim the session expired: a rejected attempt is not an expired session.
  static const invalidCredentialsMessage =
      'Invalid email or password. Please check your credentials and try again.';

  /// Matches server rejection wording for bad credentials, e.g. "Invalid
  /// email and password supplied", "Incorrect password", "credentials not
  /// valid". Other 4xx login answers (rate limit, validation) stay untouched.
  static final _credentialRejectionPattern = RegExp(
    r'(invalid|incorrect|wrong|bad|mismatch)\s+.{0,40}?(email|password|credential)'
    r'|(email|password)\s+.{0,40}?(invalid|incorrect|wrong|bad|mismatch)'
    r'|credential',
    caseSensitive: false,
  );

  /// Message the login screen shows for a failed email+password attempt.
  /// Wrong credentials may arrive as a 4xx carrying per-credential wording
  /// ("Invalid email and password supplied") or as a 401; both are wrong
  /// credentials on this route, so both get [invalidCredentialsMessage].
  /// Network, timeout, rate limit and server problems keep their real
  /// messages, so the screen never hides an unrelated failure cause.
  static String loginFailureMessage(ApiFailure failure) {
    if (failure.kind == ApiFailureKind.unauthorized) {
      return AuthNotifier.invalidCredentialsMessage;
    }
    if (failure.kind == ApiFailureKind.client &&
        _credentialRejectionPattern.hasMatch(failure.message)) {
      return AuthNotifier.invalidCredentialsMessage;
    }
    return failure.friendlyMessage;
  }

  @override
  AuthState build() {
    _repository = ref.read(authRepositoryProvider);
    _storage = locator<SecureStorageService>();
    _interceptor = locator<AuthInterceptor>();
    ref.onDispose(() {
      _disposed = true;
      _interceptor.onUnauthorized = null;
      _statusExpiryTimer?.cancel();
    });
    // Whenever the user (or their status) changes, re-arm the "Clear after" timer.
    listenSelf((_, next) => _scheduleStatusExpiry(next));

    // Signing out or in must never show the other session's data, however
    // the session changed (logout, expired token, login, magic link, Google).
    listenSelf((previous, next) {
      final changedSession =
          (previous?.status == AuthStatus.authenticated &&
              next.status == AuthStatus.unauthenticated) ||
          (previous?.status == AuthStatus.unauthenticated &&
              next.status == AuthStatus.authenticated);
      if (changedSession) _resetSessionData();
    });

    _interceptor.onUnauthorized = () {
      if (_disposed || !ref.mounted) return;
      AppLogger.w('Unauthorized — clearing session', tag: _tag);
      // Only a session that was signed in expired: a 401 from a login attempt
      // or a session restore is not one, and further 401s from requests that
      // were already in flight must not repeat the message.
      final wasSignedIn = state.status == AuthStatus.authenticated;
      _bumpSession();
      ref.read(userMenuStateProvider.notifier).reset();
      state = AuthState(
        status: AuthStatus.unauthenticated,
        sessionExpired: wasSignedIn,
      );
    };
    _restoreSession();
    return const AuthState(status: AuthStatus.unknown);
  }

  /// Rebuilds everything that belongs to one signed-in session. These providers
  /// live in the root scope, so they otherwise outlast sign-out.
  void _resetSessionData() {
    ref
      ..invalidate(workspaceProvider)
      ..invalidate(userProfileNotifierProvider)
      ..invalidate(creditsNotifierProvider)
      ..invalidate(channelProvider)
      ..invalidate(dmListProvider)
      ..invalidate(selectedDmProvider)
      ..invalidate(dmConversationActionsProvider)
      ..invalidate(chatHistoryProvider)
      ..invalidate(activeChatProvider)
      ..invalidate(activeCallProvider)
      ..invalidate(groupDmProvider)
      ..invalidate(homeSidebarProvider)
      ..invalidate(personalProfilePanelProvider)
      ..invalidate(notificationSettingsProvider)
      ..invalidate(filesProvider)
      ..invalidate(filesListProvider)
      ..invalidate(foldersListProvider);
  }

  /// Invalidates every in-flight status request and releases the presence
  /// guard so a fresh session is never blocked by an older one.
  void _bumpSession() {
    _sessionGeneration++;
    _presenceToggleInFlight = false;
    // Drop writes still waiting in the queue (their send-time session check
    // skips them) and start a fresh chain so the new session is never blocked
    // behind an older one. Requests already sent to the backend are beyond
    // client control.
    _onlineWriteTail = Future<void>.value();
    _clearConfirmedOnline();
    _confirmedCustomStatus = null;
    _mutationsStarted.removeWhere(
      (k, _) => k.sessionGeneration < _sessionGeneration - 1,
    );
    _mutationsCompleted.removeWhere(
      (k, _) => k.sessionGeneration < _sessionGeneration - 1,
    );
  }

  /// The presence value the next server write should carry: the last
  /// confirmed toggle or status write for the current session and identity,
  /// falling back to the current user state.
  bool _currentPresenceForSend() {
    final user = state.user;
    if (_confirmedOnline != null &&
        _confirmedOnlineSessionGeneration == _sessionGeneration &&
        _confirmedOnlineUserId == user?.id &&
        _confirmedOnlineOrgId == user?.currentOrg) {
      return _confirmedOnline!;
    }
    return user?.status.online ?? true;
  }

  /// Runs [operation] once every previous online-writing request has
  /// completed, re-checking the session and context at send time. Resolves
  /// `null` when the write was dropped (disposed, or the session/context
  /// changed while it waited in the queue).
  Future<T?> _enqueueOnlineWrite<T>(
    Future<T> Function() operation, {
    required int sessionGeneration,
    required String? userId,
    required String? orgId,
  }) {
    final task = _onlineWriteTail.then((_) async {
      if (_disposed ||
          _sessionGeneration != sessionGeneration ||
          state.status != AuthStatus.authenticated ||
          state.user?.id != userId ||
          state.user?.currentOrg != orgId) {
        return null;
      }
      return operation();
    });
    // Keep the chain alive regardless of individual outcomes; each
    // operation maps its own failures to Result.
    _onlineWriteTail = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }

  void _syncMenuPresence(User user) {
    ref.read(userMenuStateProvider.notifier).setAway(!user.status.online);
  }

  void _adoptSessionUser(User user) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
    _syncMenuPresence(user);
    _setConfirmedOnline(
      online: user.status.online,
      sessionGeneration: _sessionGeneration,
      userId: user.id,
      orgId: user.currentOrg,
    );
    _confirmedCustomStatus = _ConfirmedCustomStatus(
      emoji: user.status.emoji,
      text: user.status.text,
      expiresAt: user.status.expiresAt,
      pauseNotifications: user.status.pauseNotifications,
      sessionGeneration: _sessionGeneration,
      userId: user.id,
      orgId: user.currentOrg,
    );
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
        _adoptSessionUser(result.value);
      case Failure<User>():
        final failure = result.error;
        if (failure.kind == ApiFailureKind.unauthorized) {
          // The server rejected the token, so it is really invalid.
          AppLogger.w(
            'Session restore rejected (401) — clearing token',
            tag: _tag,
          );
          await _storage.deleteAccessToken();
          state = const AuthState(status: AuthStatus.unauthenticated);
        } else {
          // Network, timeout or server problem: the token may still be valid.
          // Keep it, and let the user try again instead of signing in again.
          AppLogger.w(
            'Session restore failed (${failure.kind.name}) — keeping token',
            tag: _tag,
          );
          state = AuthState(
            status: AuthStatus.unauthenticated,
            error: failure.friendlyMessage,
            sessionRestoreFailed: true,
          );
        }
    }
  }

  /// Tries the saved session again after the server could not be reached.
  Future<void> retrySessionRestore() async {
    state = const AuthState(status: AuthStatus.unknown);
    await _restoreSession();
  }

  /// Leaves the retry screen for the login form. The token is kept, so the next
  /// launch still tries to restore the session.
  void showLoginForm() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Saves the token from a successful sign-in. If the keychain write fails
  /// (locked keychain, missing entitlement, broken keyring) the sign-in still
  /// completes: the token is kept in memory for this run, as when Remember me
  /// is off, instead of the error escaping and leaving the sign-in spinner
  /// running forever (Ziki #3485).
  Future<void> _saveSessionToken(String token, {bool persist = true}) async {
    try {
      await _storage.saveAccessToken(token, persist: persist);
    } catch (error) {
      AppLogger.w(
        'Could not save the session token; keeping it for this run only '
        '- $error',
        tag: _tag,
      );
      try {
        // Sets the in-memory token before touching the keychain, so the
        // session works even if this keychain call fails as well.
        await _storage.saveAccessToken(token, persist: false);
      } catch (_) {}
    }
  }

  /// With [rememberMe] false the session lasts until the app closes.
  Future<void> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    AppLogger.d('Login attempt — $email', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.login(email: email, password: password);
    switch (result) {
      case Success<AuthSession>():
        AppLogger.i('Login succeeded — saving token', tag: _tag);
        await _saveSessionToken(result.value.accessToken, persist: rememberMe);
        state = AuthState(
          status: AuthStatus.authenticated,
          user: result.value.user,
          isLoading: false,
        );
        _bumpSession();
        _adoptSessionUser(result.value.user);
      case Failure<AuthSession>():
        AppLogger.w('Login rejected — ${result.error.message}', tag: _tag);
        state = state.copyWith(
          isLoading: false,
          error: loginFailureMessage(result.error),
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
          'Magic link verification succeeded — saving token',
          tag: _tag,
        );
        await _saveSessionToken(result.value.accessToken);
        _bumpSession();
        _adoptSessionUser(result.value.user);
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
    // Unsent DM drafts are private: don't leave them on a shared computer.
    final userId = state.user?.id;
    if (userId != null && userId.isNotEmpty) {
      try {
        await DmDraftStore.deleteAllForUser(_storage, userId);
      } catch (error) {
        AppLogger.w('Could not remove drafts on logout - $error', tag: _tag);
      }
    }
    await _storage.deleteAccessToken();
    _bumpSession();
    ref.read(userMenuStateProvider.notifier).reset();
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

  /// Re-fetches the signed-in user and applies the fresh snapshot.
  ///
  /// A snapshot that overlaps a local presence or status mutation — one was
  /// in flight when the refresh started, or one started while the refresh was
  /// in flight — is merged with the locally newer status instead of replacing
  /// it, so a slower refresh can never revert a confirmed change while still
  /// bringing in fresh profile data. With no overlap the snapshot is adopted
  /// wholesale, including a legitimately changed server-side presence.
  Future<void> refreshCurrentUser() async {
    final requested = state.user;
    if (_disposed ||
        state.status != AuthStatus.authenticated ||
        requested == null) {
      return;
    }
    final sessionGeneration = _sessionGeneration;
    final context = _MutationContext(
      sessionGeneration: sessionGeneration,
      userId: requested.id,
      orgId: requested.currentOrg,
    );
    final mutationsStarted = _getMutationsStarted(context);
    final mutationsCompleted = _getMutationsCompleted(context);

    final result = await _repository.getCurrentUser();

    if (_disposed ||
        _sessionGeneration != sessionGeneration ||
        state.status != AuthStatus.authenticated) {
      AppLogger.d('Discarding stale user refresh', tag: _tag);
      return;
    }
    final current = state.user;
    if (current == null ||
        current.id != requested.id ||
        current.currentOrg != requested.currentOrg) {
      AppLogger.d(
        'Discarding user refresh — session context changed',
        tag: _tag,
      );
      return;
    }

    switch (result) {
      case Success<User>():
        final fresh = result.value;
        final User adopted;
        final orgChanged = fresh.currentOrg != current.currentOrg;
        final currentMutationsStarted = _getMutationsStarted(context);
        if (!orgChanged &&
            (mutationsCompleted < mutationsStarted ||
                currentMutationsStarted != mutationsStarted)) {
          // The snapshot predates or overlaps local mutations in the same
          // org: keep the locally newer status and take only the fresh profile fields.
          adopted = fresh._withStatus(current.status);
        } else {
          // If the server's fresh profile contains custom status, adopt it.
          // Otherwise preserve locally confirmed status while adopting the
          // server's latest presence. Do not carry them into a different organisation.
          final UserStatus resolvedStatus;
          if (orgChanged) {
            resolvedStatus = fresh.status;
          } else if (fresh.status.hasCustomStatus) {
            resolvedStatus = fresh.status;
          } else if (current.status.hasCustomStatus) {
            resolvedStatus = current.status.copyWith(
              online: fresh.status.online,
            );
          } else {
            resolvedStatus = fresh.status;
          }
          adopted = orgChanged ? fresh : fresh._withStatus(resolvedStatus);
          _setConfirmedOnline(
            online: fresh.status.online,
            sessionGeneration: sessionGeneration,
            userId: fresh.id,
            orgId: fresh.currentOrg,
          );
          _confirmedCustomStatus = _ConfirmedCustomStatus(
            emoji: adopted.status.emoji,
            text: adopted.status.text,
            expiresAt: adopted.status.expiresAt,
            pauseNotifications: adopted.status.pauseNotifications,
            sessionGeneration: sessionGeneration,
            userId: fresh.id,
            orgId: fresh.currentOrg,
          );
        }
        state = state.copyWith(user: adopted);
        _syncMenuPresence(adopted);
      case Failure<User>():
        AppLogger.w(
          'Failed to refresh user — ${result.error.message}',
          tag: _tag,
        );
    }
  }

  Future<void> loginWithGoogle({bool rememberMe = true}) async {
    AppLogger.d('Google Sign-In attempt', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    HttpServer? server;
    Timer? deadline;
    try {
      final config = locator<AppConfig>();

      // 1. Bind to a localhost port to intercept the redirect. Prefer the
      // conventional port; when another app holds it, fall back to a port the
      // OS assigns (Google accepts any port on a loopback redirect URI).
      late final HttpServer bound;
      try {
        bound = await HttpServer.bind(InternetAddress.loopbackIPv4, 8000);
      } on SocketException {
        bound = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }
      server = bound;
      final port = bound.port;
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
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);

      // 3. Wait for Google's redirect containing the authorization code
      String? grantCode;
      String? callbackError;
      // server.timeout only fires on an established idle connection: a closed
      // browser tab or a redirect that never arrives leaves no connection, so
      // cap the whole wait with a deadline that ends the stream and lets the
      // null-code path below clear isLoading.
      deadline = Timer(googleSignInWait, () {
        server?.close(force: true);
      });
      await for (final request in server.timeout(
        const Duration(seconds: 60),
        onTimeout: (sink) {
          sink.addError(TimeoutException('Google Sign-In redirect timed out'));
        },
      )) {
        final oauthError = request.uri.queryParameters['error'];
        grantCode = request.uri.queryParameters['code'];
        if (oauthError != null ||
            grantCode == null ||
            grantCode.trim().isEmpty) {
          grantCode = null;
          callbackError = oauthError == 'access_denied'
              ? 'Google sign-in was cancelled.'
              : 'Google sign-in failed. Please try again.';
        }
        final title = callbackError == null
            ? 'Authentication Successful'
            : 'Authentication Unsuccessful';
        final heading = callbackError == null
            ? 'Sign In Successful!'
            : oauthError == 'access_denied'
            ? 'Sign In Cancelled'
            : 'Sign In Failed';
        final message = callbackError == null
            ? 'You have successfully authenticated with Zedu. You can now close this tab and return to the application.'
            : '$callbackError You can close this tab and return to Zedu to try again.';

        // Render fixed messages rather than reflecting OAuth query values.
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
                h1 { color: ${callbackError == null ? '#4CAF50' : 'inherit'}; margin-top: 0; }
                p { color: #666; font-size: 16px; }
              </style>
            </head>
            <body>
              <div class="card">
                <h1>$heading</h1>
                <p>$message</p>
              </div>
            </body>
            </html>
          ''');
        await request.response.close();
        break;
      }
      deadline.cancel();

      await server.close();
      server = null;

      if (grantCode == null) {
        AppLogger.w('Google Sign-In aborted or code not found', tag: _tag);
        state = state.copyWith(
          isLoading: false,
          error: callbackError ?? 'Google sign-in failed. Please try again.',
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
      switch (result) {
        case Success<AuthSession>():
          AppLogger.i(
            rememberMe
                ? 'Google Sign-In succeeded · token persisted'
                : 'Google Sign-In succeeded · token kept for this run only',
            tag: _tag,
          );
          await _saveSessionToken(
            result.value.accessToken,
            persist: rememberMe,
          );
          _bumpSession();
          _adoptSessionUser(result.value.user);
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
    } on TimeoutException {
      AppLogger.w('Google Sign-In timed out', tag: _tag);
      state = state.copyWith(
        isLoading: false,
        error: 'Google Sign-In timed out. Please try again.',
      );
    } catch (e) {
      AppLogger.e('Google Sign-In failed', tag: _tag, error: e);
      state = state.copyWith(isLoading: false, error: 'Google Sign-In failed');
    } finally {
      deadline?.cancel();
      await server?.close();
    }
  }

  // ── Status / Presence ────────────────────────────────────────────────────────

  /// Updates user's custom status. The online flag is not a parameter: the
  /// server write carries the latest confirmed presence at send time, so a
  /// status dialog opened earlier can never push a stale presence value to
  /// the backend. On success, the owned status fields are applied to the
  /// local [AuthState.user] immediately so every widget watching
  /// [authNotifierProvider] reacts without a re-fetch.
  Future<bool> changeStatus({
    required String icon,
    required String text,
    required StatusTimeout timeout,
    required bool pauseNotifications,
  }) async {
    final currentUser = state.user;
    if (currentUser == null || state.status != AuthStatus.authenticated) {
      return false;
    }

    AppLogger.d('changeStatus — "$text"', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final mutationSeq = ++_statusMutationSeq;
    final sessionGeneration = _sessionGeneration;
    final userId = currentUser.id;
    final orgId = currentUser.currentOrg;
    final context = _MutationContext(
      sessionGeneration: sessionGeneration,
      userId: userId,
      orgId: orgId,
    );
    _recordMutationStarted(context);
    try {
      bool? sentOnline;
      final result = await _enqueueOnlineWrite<Result<void>>(
        () async {
          sentOnline = _currentPresenceForSend();
          AppLogger.d(
            'changeStatus send — "$text" online=$sentOnline',
            tag: _tag,
          );
          final response = await _repository.changeStatus(
            icon: icon,
            text: text,
            pauseNotifications: pauseNotifications,
            statusTimeout: timeout.apiValue,
            clearStatus: false,
            online: sentOnline!,
          );
          // Confirmed presence and custom status are recorded inside the queue
          // task: the next queued write runs one microtask before this caller
          // resumes, and must observe the values this write just persisted.
          if (!_disposed &&
              _sessionGeneration == sessionGeneration &&
              state.status == AuthStatus.authenticated &&
              state.user?.id == userId &&
              state.user?.currentOrg == orgId &&
              response is Success<void>) {
            _setConfirmedOnline(
              online: sentOnline!,
              sessionGeneration: sessionGeneration,
              userId: userId,
              orgId: orgId,
            );
            _confirmedCustomStatus = _ConfirmedCustomStatus(
              emoji: icon.isEmpty ? null : icon,
              text: text.isEmpty ? null : text,
              expiresAt: _expiryFromTimeout(timeout),
              pauseNotifications: pauseNotifications,
              sessionGeneration: sessionGeneration,
              userId: userId,
              orgId: orgId,
            );
          }
          return response;
        },
        sessionGeneration: sessionGeneration,
        userId: userId,
        orgId: orgId,
      );

      if (result == null) {
        _resetDiscardedStatusLoading(
          sessionGeneration: sessionGeneration,
          mutationSeq: mutationSeq,
          userId: userId,
        );
        // Dropped before send (disposed, or the session changed while the
        // write waited in the queue) — no feedback for a dead session.
        return false;
      }
      if (_disposed ||
          _sessionGeneration != sessionGeneration ||
          state.status != AuthStatus.authenticated ||
          state.user?.id != userId ||
          state.user?.currentOrg != orgId) {
        _resetDiscardedStatusLoading(
          sessionGeneration: sessionGeneration,
          mutationSeq: mutationSeq,
          userId: userId,
        );
        return false;
      }

      switch (result) {
        case Success<void>():
          AppLogger.i('Status changed successfully', tag: _tag);
          // Apply owned status fields to the LATEST user state so concurrent
          // updates are preserved, and only while no newer mutation has
          // started; presence (online) is owned by the presence flow.
          if (mutationSeq == _statusMutationSeq) {
            final latest = state.user;
            if (latest != null) {
              final updatedStatus = UserStatus(
                emoji: icon.isEmpty ? null : icon,
                text: text.isEmpty ? null : text,
                expiresAt: _expiryFromTimeout(timeout),
                pauseNotifications: pauseNotifications,
                online: latest.status.online,
              );
              state = state.copyWith(
                isLoading: false,
                user: latest._withStatus(updatedStatus),
                clearError: true,
              );
              return true;
            }
          }
          state = state.copyWith(isLoading: false);
          return true;

        case Failure<void>():
          AppLogger.w(
            'Status change failed — ${result.error.message}',
            tag: _tag,
          );
          if (mutationSeq == _statusMutationSeq) {
            final confirmed = _confirmedCustomStatus;
            final latest = state.user;
            if (confirmed != null &&
                latest != null &&
                confirmed.sessionGeneration == sessionGeneration &&
                confirmed.userId == userId &&
                confirmed.orgId == orgId) {
              final reconciledStatus = UserStatus(
                emoji: confirmed.emoji,
                text: confirmed.text,
                expiresAt: confirmed.expiresAt,
                pauseNotifications: confirmed.pauseNotifications,
                online: latest.status.online,
              );
              state = state.copyWith(
                isLoading: false,
                user: latest._withStatus(reconciledStatus),
                error: result.error.friendlyMessage,
              );
              return false;
            }
          }
          state = state.copyWith(
            isLoading: false,
            error: result.error.friendlyMessage,
          );
          return false;
      }
    } finally {
      _recordMutationCompleted(context);
    }
  }

  /// Clears the current custom status while keeping presence unchanged. The
  /// server write carries the latest confirmed presence at send time, like
  /// [changeStatus].
  Future<bool> clearStatus() async {
    final currentUser = state.user;
    if (currentUser == null || state.status != AuthStatus.authenticated) {
      return false;
    }

    AppLogger.d('clearStatus', tag: _tag);
    state = state.copyWith(isLoading: true, clearError: true);

    final mutationSeq = ++_statusMutationSeq;
    final sessionGeneration = _sessionGeneration;
    final userId = currentUser.id;
    final orgId = currentUser.currentOrg;
    final context = _MutationContext(
      sessionGeneration: sessionGeneration,
      userId: userId,
      orgId: orgId,
    );
    _recordMutationStarted(context);
    try {
      bool? sentOnline;
      final result = await _enqueueOnlineWrite<Result<void>>(
        () async {
          sentOnline = _currentPresenceForSend();
          final response = await _repository.changeStatus(
            icon: '',
            text: '',
            pauseNotifications: false,
            statusTimeout: StatusTimeout.dontRemove.apiValue,
            clearStatus: true,
            online: sentOnline!,
          );
          // Same in-task bookkeeping as [changeStatus]: the next queued write
          // runs before this caller resumes.
          if (!_disposed &&
              _sessionGeneration == sessionGeneration &&
              state.status == AuthStatus.authenticated &&
              state.user?.id == userId &&
              state.user?.currentOrg == orgId &&
              response is Success<void>) {
            _setConfirmedOnline(
              online: sentOnline!,
              sessionGeneration: sessionGeneration,
              userId: userId,
              orgId: orgId,
            );
            _confirmedCustomStatus = _ConfirmedCustomStatus(
              emoji: null,
              text: null,
              expiresAt: null,
              pauseNotifications: false,
              sessionGeneration: sessionGeneration,
              userId: userId,
              orgId: orgId,
            );
          }
          return response;
        },
        sessionGeneration: sessionGeneration,
        userId: userId,
        orgId: orgId,
      );

      if (result == null) {
        _resetDiscardedStatusLoading(
          sessionGeneration: sessionGeneration,
          mutationSeq: mutationSeq,
          userId: userId,
        );
        return false;
      }
      if (_disposed ||
          _sessionGeneration != sessionGeneration ||
          state.status != AuthStatus.authenticated ||
          state.user?.id != userId ||
          state.user?.currentOrg != orgId) {
        _resetDiscardedStatusLoading(
          sessionGeneration: sessionGeneration,
          mutationSeq: mutationSeq,
          userId: userId,
        );
        return false;
      }

      switch (result) {
        case Success<void>():
          if (mutationSeq == _statusMutationSeq) {
            final latest = state.user;
            if (latest != null) {
              state = state.copyWith(
                isLoading: false,
                user: latest._withStatus(
                  UserStatus(online: latest.status.online),
                ),
                clearError: true,
              );
              return true;
            }
          }
          state = state.copyWith(isLoading: false);
          return true;
        case Failure<void>():
          if (mutationSeq == _statusMutationSeq) {
            final confirmed = _confirmedCustomStatus;
            final latest = state.user;
            if (confirmed != null &&
                latest != null &&
                confirmed.sessionGeneration == sessionGeneration &&
                confirmed.userId == userId &&
                confirmed.orgId == orgId) {
              final reconciledStatus = UserStatus(
                emoji: confirmed.emoji,
                text: confirmed.text,
                expiresAt: confirmed.expiresAt,
                pauseNotifications: confirmed.pauseNotifications,
                online: latest.status.online,
              );
              state = state.copyWith(
                isLoading: false,
                user: latest._withStatus(reconciledStatus),
                error: result.error.friendlyMessage,
              );
              return false;
            }
          }
          state = state.copyWith(
            isLoading: false,
            error: result.error.friendlyMessage,
          );
          return false;
      }
    } finally {
      _recordMutationCompleted(context);
    }
  }

  /// Toggles between Active (online=true) and Away (online=false) through the
  /// dedicated `POST /profile/presence` endpoint, which writes only the
  /// online flag — custom status text, emoji, expiry and notification
  /// preferences are never sent or changed.
  ///
  /// Returns [PresenceConfirmed] only when the backend confirmed the change
  /// and the confirming session is still current; [PresenceFailed] carries
  /// the error message for a genuine failure; [PresenceSkipped] covers
  /// duplicate clicks and responses that arrive after a logout, account or
  /// organisation change (discarded silently).
  Future<PresenceToggleResult> toggleOnlineStatus() async {
    final currentUser = state.user;
    if (currentUser == null || state.status != AuthStatus.authenticated) {
      return const PresenceSkipped();
    }
    // Ignore clicks while a toggle request is already in flight.
    if (_presenceToggleInFlight) {
      return const PresenceSkipped();
    }
    _presenceToggleInFlight = true;

    final sessionGeneration = _sessionGeneration;
    final userId = currentUser.id;
    final orgId = currentUser.currentOrg;
    final context = _MutationContext(
      sessionGeneration: sessionGeneration,
      userId: userId,
      orgId: orgId,
    );
    _recordMutationStarted(context);

    AppLogger.d('toggleOnlineStatus requested', tag: _tag);

    try {
      bool sentOnline = false;
      final result = await _enqueueOnlineWrite<Result<void>>(
        () async {
          // Flip from the latest known presence at send time: an earlier
          // queued write may have changed it since the click.
          sentOnline = !_currentPresenceForSend();
          AppLogger.d('toggleOnlineStatus → online=$sentOnline', tag: _tag);
          final response = await _repository.setPresence(online: sentOnline);
          // Record the confirmed presence inside the queue task: the next
          // queued write runs one microtask before this caller resumes.
          if (!_disposed &&
              _sessionGeneration == sessionGeneration &&
              state.status == AuthStatus.authenticated &&
              state.user?.id == userId &&
              state.user?.currentOrg == orgId &&
              response is Success<void>) {
            _setConfirmedOnline(
              online: sentOnline,
              sessionGeneration: sessionGeneration,
              userId: userId,
              orgId: orgId,
            );
          }
          return response;
        },
        sessionGeneration: sessionGeneration,
        userId: userId,
        orgId: orgId,
      );

      if (result == null) {
        AppLogger.d('Presence toggle dropped before send', tag: _tag);
        return const PresenceSkipped();
      }

      // Discard a stale response: the session, account or organisation
      // changed while the request was in flight, so it no longer applies.
      if (_disposed ||
          _sessionGeneration != sessionGeneration ||
          state.status != AuthStatus.authenticated ||
          state.user?.id != userId ||
          state.user?.currentOrg != orgId) {
        AppLogger.d('Discarding stale presence response', tag: _tag);
        return const PresenceSkipped();
      }

      switch (result) {
        case Success<void>():
          AppLogger.i('Presence toggled — online=$sentOnline', tag: _tag);
          // Apply the confirmed flag to the LATEST user object so concurrent
          // profile or status updates made while the request was in flight
          // are preserved.
          final latest = state.user!;
          state = state.copyWith(
            user: latest._withStatus(
              latest.status.copyWith(online: sentOnline),
            ),
            clearError: true,
          );
          _syncMenuPresence(state.user!);
          return const PresenceConfirmed();
        case Failure<void>():
          AppLogger.w(
            'Presence toggle failed — ${result.error.message}',
            tag: _tag,
          );
          final message = result.error.friendlyMessage;
          state = state.copyWith(error: message);
          return PresenceFailed(message);
      }
    } finally {
      // Release the guard only for the session this request belongs to; a
      // session boundary already released it for the next session.
      if (_sessionGeneration == sessionGeneration) {
        _presenceToggleInFlight = false;
      }
      _recordMutationCompleted(context);
    }
  }

  DateTime? _expiryFromTimeout(StatusTimeout timeout) =>
      timeout.expiryFrom(DateTime.now());

  Timer? _statusExpiryTimer;

  /// Arms one timer for the current custom status's "Clear after" time, so it
  /// disappears while the app stays open. A status that has already expired is
  /// cleared straight away. Signing out or changing the status re-arms it.
  void _scheduleStatusExpiry(AuthState next) {
    _statusExpiryTimer?.cancel();
    _statusExpiryTimer = null;
    final status = next.user?.status;
    final expiresAt = status?.expiresAt;
    if (status == null || expiresAt == null) return;
    if (status.emoji == null && (status.text ?? '').isEmpty) return;
    final left = expiresAt.difference(DateTime.now());
    _statusExpiryTimer = Timer(
      left.isNegative ? Duration.zero : left,
      _clearExpiredStatus,
    );
  }

  void _clearExpiredStatus() {
    final user = state.user;
    final expiresAt = user?.status.expiresAt;
    if (_disposed || user == null || expiresAt == null) return;
    // The status may have been changed since the timer was armed.
    if (DateTime.now().isBefore(expiresAt)) return;
    AppLogger.d('custom status expired — clearing', tag: _tag);
    state = state.copyWith(user: user._withStatus(user.status.cleared()));
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

class _MutationContext {
  final int sessionGeneration;
  final String? userId;
  final String? orgId;

  const _MutationContext({
    required this.sessionGeneration,
    required this.userId,
    required this.orgId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MutationContext &&
          runtimeType == other.runtimeType &&
          sessionGeneration == other.sessionGeneration &&
          userId == other.userId &&
          orgId == other.orgId;

  @override
  int get hashCode => Object.hash(sessionGeneration, userId, orgId);
}

class _ConfirmedCustomStatus {
  final String? emoji;
  final String? text;
  final DateTime? expiresAt;
  final bool pauseNotifications;
  final int sessionGeneration;
  final String? userId;
  final String? orgId;

  const _ConfirmedCustomStatus({
    this.emoji,
    this.text,
    this.expiresAt,
    this.pauseNotifications = false,
    required this.sessionGeneration,
    required this.userId,
    required this.orgId,
  });
}
