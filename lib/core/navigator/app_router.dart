import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class AppRouter {
  const AppRouter._();

  static const home = '/home';
  static const threads = '/threads';
  static const later = '/later';
  static const notifications = '/notifications';
  static const login = '/login';
  static const magicLinkRequest = '/magic-link';
  static const magicLinkSent = '/magic-link/sent';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const changePassword = '/change-password';
  static const profile = '/profile';
  static const createOrganization = '/create-organization';
  static const buyCredits = '/credits/buy';
  static const welcome = '/welcome';

  /// Set once Get Started is pressed on the welcome screen.
  static const welcomeSeenKey = 'welcome_seen';

  /// Where the app opens. [main] sets it with [resolveStartLocation] before
  /// the router is first used.
  static String startLocation = login;

  /// The welcome screen on a first launch (no saved session and the welcome
  /// screen never dismissed), otherwise the usual login route, from which a
  /// saved session still goes on to Home. Any storage error falls back to
  /// login, so startup never depends on this.
  static Future<String> resolveStartLocation(
    SecureStorageService storage,
  ) async {
    try {
      final token = await storage.getAccessToken();
      final seen = await storage.readData(welcomeSeenKey);
      return token == null && seen == null ? welcome : login;
    } catch (_) {
      return login;
    }
  }

  /// The root Navigator. Widgets mounted from [App]'s `builder` sit above the
  /// Navigator, so they reach the Overlay and the router through this key
  /// instead of through their own context.
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// The auth status the router guards on. [SessionExpiryListener] keeps it
  /// in sync with `authNotifierProvider`.
  static final authStatus = ValueNotifier<AuthStatus>(AuthStatus.unknown);

  /// Routes that stay reachable while signed out. Change password is part of
  /// the signed-out reset flow ("Use current password").
  static const publicPaths = {
    welcome,
    login,
    magicLinkRequest,
    magicLinkSent,
    signup,
    forgotPassword,
    resetPassword,
    changePassword,
  };

  /// Auth entry routes that an authenticated user is redirected away from to [home].
  static const authEntryPaths = {
    login,
    magicLinkRequest,
    magicLinkSent,
    signup,
    forgotPassword,
    resetPassword,
  };

  /// Sends a signed-out user on a protected route to the login page, and an
  /// authenticated user on an entry auth route to the home page.
  /// Nothing redirects while the status is still [AuthStatus.unknown] (the saved
  /// session is being restored).
  static String? redirectSignedOut(GoRouterState state) {
    final status = authStatus.value;
    final path = state.uri.path;

    if (status == AuthStatus.unauthenticated) {
      return publicPaths.contains(path) ? null : login;
    }

    if (status == AuthStatus.authenticated && authEntryPaths.contains(path)) {
      return home;
    }

    return null;
  }

  static final router = GoRouter(
    initialLocation: startLocation,
    navigatorKey: navigatorKey,
    refreshListenable: authStatus,
    redirect: (context, state) => redirectSignedOut(state),
    routes: [
      GoRoute(path: welcome, builder: (context, state) => const WelcomeView()),
      GoRoute(path: login, builder: (context, state) => const LoginView()),
      GoRoute(
        path: magicLinkRequest,
        builder: (context, state) => const MagicLinkRequestView(),
      ),
      GoRoute(
        path: magicLinkSent,
        redirect: (context, state) =>
            state.extra is String && (state.extra! as String).trim().isNotEmpty
            ? null
            : magicLinkRequest,
        builder: (context, state) {
          final email = state.extra is String ? state.extra! as String : '';
          return MagicLinkSentView(email: email);
        },
      ),

      GoRoute(path: home, builder: (context, state) => const HomeView()),
      GoRoute(path: threads, builder: (context, state) => const ThreadsView()),
      GoRoute(path: later, builder: (context, state) => const LaterView()),
      GoRoute(
        path: notifications,
        builder: (context, state) => const NotificationCenterView(),
      ),
      GoRoute(path: signup, builder: (context, state) => const SignUpView()),
      GoRoute(
        path: forgotPassword,
        builder: (context, state) => const ForgotPasswordView(),
      ),
      GoRoute(
        path: resetPassword,
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return ResetPasswordView(email: email);
        },
      ),
      GoRoute(
        path: changePassword,
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return ChangePasswordView(email: email);
        },
      ),
      GoRoute(
        path: profile,
        builder: (context, state) => const UserProfileView(),
      ),
      GoRoute(
        path: createOrganization,
        builder: (context, state) => const CreateOrganizationView(),
      ),
      GoRoute(
        path: buyCredits,
        builder: (context, state) => const BuyCreditsView(),
      ),
    ],
  );
}
