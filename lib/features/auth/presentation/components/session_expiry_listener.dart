import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Keeps [AppRouter.authStatus] in sync with the auth state, so the router
/// sends a signed-out user back to the login page, and shows the
/// session-expired message once when a 401 ends the session.
class SessionExpiryListener extends ConsumerStatefulWidget {
  const SessionExpiryListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionExpiryListener> createState() =>
      _SessionExpiryListenerState();
}

class _SessionExpiryListenerState extends ConsumerState<SessionExpiryListener> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<AuthState>(
      authNotifierProvider,
      _onAuthChanged,
      fireImmediately: true,
    );
  }

  void _onAuthChanged(AuthState? previous, AuthState next) {
    AppRouter.authStatus.value = next.status;

    if (previous?.status != AuthStatus.authenticated ||
        next.status != AuthStatus.unauthenticated ||
        !next.sessionExpired) {
      return;
    }

    // Mounted from `App`'s builder, above the Navigator, so the toast goes
    // through the root navigator's Overlay.
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return;
    AppToastService.showAtRoot(
      navigator,
      type: AppToastType.error,
      message: AuthNotifier.sessionExpiredMessage,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
