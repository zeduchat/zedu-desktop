import 'dart:async';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class AuthDeepLinkListener extends ConsumerStatefulWidget {
  const AuthDeepLinkListener({super.key, required this.child, this.appLinks});

  final Widget child;
  final AppLinks? appLinks;

  @override
  ConsumerState<AuthDeepLinkListener> createState() =>
      _AuthDeepLinkListenerState();
}

class _AuthDeepLinkListenerState extends ConsumerState<AuthDeepLinkListener> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastProcessedToken;

  /// Token whose verification is still running, so a duplicate event for the
  /// same link doesn't start a second attempt before the first finishes.
  String? _verifyingToken;

  static const _tag = 'AuthDeepLinkListener';

  @override
  void initState() {
    super.initState();
    _appLinks = widget.appLinks ?? AppLinks();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (error) {
      AppLogger.w('Failed to read initial deep link', tag: _tag);
    }

    if (!mounted) return;

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        unawaited(_handleUri(uri));
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.w('Deep link stream error: $error', tag: _tag);
      },
    );
  }

  Future<void> _handleUri(Uri uri) async {
    final token = MagicLinkDeepLinkParser.extractToken(uri);
    if (token == null || token == _lastProcessedToken) return;
    // A retry for the same link is only allowed once the current attempt has
    // settled; otherwise the same token would kick off parallel verifications.
    if (_verifyingToken != null) return;
    _verifyingToken = token;
    // Every way out of the attempt (declined, unmounted, finished) must clear
    // the guard, or every later link is dropped.
    try {
      await _verifyToken(token);
    } finally {
      _verifyingToken = null;
    }
  }

  Future<void> _verifyToken(String token) async {
    // A link that opens the app arrives while the saved session is still
    // being restored, so wait to know whether someone is signed in.
    final status = await _settledAuthStatus();
    if (!mounted) return;

    // Never switch accounts silently: anyone can send a link to their own
    // account, and following it would put you in theirs.
    if (status == AuthStatus.authenticated) {
      final switchAccount = await _confirmSwitchAccount();
      if (!mounted) return;
      if (!switchAccount) {
        AppLogger.i('Magic link ignored — kept the current account', tag: _tag);
        // Let the same link work if it is opened again later.
        _lastProcessedToken = null;
        return;
      }
      await ref.read(authNotifierProvider.notifier).logout();
      if (!mounted) return;
    }

    AppLogger.i('Processing magic link deep link', tag: _tag);
    await ref.read(authNotifierProvider.notifier).verifyMagicLink(token: token);
    // Only remember a token that actually succeeded, so a failed attempt (for
    // example a stale link opened while logged out) can be retried.
    final authState = ref.read(authNotifierProvider);
    if (authState.status == AuthStatus.authenticated) {
      _lastProcessedToken = token;
    }

    if (!mounted) return;

    // This listener is mounted from `App`'s builder, above the Navigator, so
    // its own context has neither an Overlay nor the router in it.
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return;

    if (authState.status == AuthStatus.authenticated) {
      AppToastService.showAtRoot(
        navigator,
        type: AppToastType.success,
        message: 'Logged in successfully!',
      );
      navigator.context.go(AppRouter.home);
      return;
    }

    if (authState.error != null) {
      AppToastService.showAtRoot(
        navigator,
        type: AppToastType.error,
        message: authState.error!,
      );
    }
  }

  /// The auth status once it is known (not [AuthStatus.unknown]).
  Future<AuthStatus> _settledAuthStatus() async {
    final current = ref.read(authNotifierProvider).status;
    if (current != AuthStatus.unknown) return current;

    final settled = Completer<AuthStatus>();
    final subscription = ref.listenManual<AuthStatus>(
      authNotifierProvider.select((s) => s.status),
      (_, next) {
        if (next != AuthStatus.unknown && !settled.isCompleted) {
          settled.complete(next);
        }
      },
    );
    try {
      return await settled.future;
    } finally {
      subscription.close();
    }
  }

  /// Asks whether to leave the signed-in account for the link's one.
  /// Returns false when there is nowhere to ask or the user declines.
  Future<bool> _confirmSwitchAccount() async {
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return false;

    final email = ref.read(authNotifierProvider).user?.email ?? '';
    final signedIn = email.isEmpty
        ? "You're already signed in."
        : "You're signed in as $email.";
    var confirmed = false;
    await showProfileConfirmDialog(
      navigator.context,
      title: 'Switch accounts?',
      message: '$signedIn Sign out and continue with this magic link?',
      confirmLabel: 'Sign out and continue',
      onConfirm: () async => confirmed = true,
    );
    return confirmed;
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
