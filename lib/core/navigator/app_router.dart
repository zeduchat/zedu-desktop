import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class AppRouter {
  const AppRouter._();

  static const home = '/home';
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
    login,
    magicLinkRequest,
    magicLinkSent,
    signup,
    forgotPassword,
    resetPassword,
    changePassword,
  };

  /// Sends a signed-out user on a signed-in route to the login page, for
  /// example after a 401 ends the session. Nothing redirects while the status
  /// is still [AuthStatus.unknown] (the saved session is being restored).
  static String? redirectSignedOut(GoRouterState state) {
    if (authStatus.value != AuthStatus.unauthenticated) return null;
    return publicPaths.contains(state.uri.path) ? null : login;
  }

  static final router = GoRouter(
    initialLocation: login,
    navigatorKey: navigatorKey,
    refreshListenable: authStatus,
    redirect: (context, state) => redirectSignedOut(state),
    routes: [
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
