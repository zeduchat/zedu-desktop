import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class FakeSessionAuthNotifier extends AuthNotifier {
  FakeSessionAuthNotifier(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;

  /// What the real notifier does when the interceptor reports a 401.
  void expire() => state = const AuthState(
    status: AuthStatus.unauthenticated,
    sessionExpired: true,
  );

  @override
  Future<void> logout() async =>
      state = const AuthState(status: AuthStatus.unauthenticated);

  void restored() => state = const AuthState(status: AuthStatus.authenticated);
}

void main() {
  group('SessionExpiryListener and the router guard', () {
    late FakeSessionAuthNotifier notifier;
    late GoRouter router;

    tearDown(() => AppRouter.authStatus.value = AuthStatus.unknown);

    // Mounts the listener exactly where App.build mounts it, with a router
    // that guards like AppRouter.router.
    Future<void> pumpApp(
      WidgetTester tester, {
      required AuthState initial,
      String initialLocation = AppRouter.home,
    }) async {
      notifier = FakeSessionAuthNotifier(initial);
      Widget page(String name) => Scaffold(body: Text(name));
      router = GoRouter(
        initialLocation: initialLocation,
        navigatorKey: AppRouter.navigatorKey,
        refreshListenable: AppRouter.authStatus,
        redirect: (context, state) => AppRouter.redirectSignedOut(state),
        routes: [
          GoRoute(path: AppRouter.login, builder: (_, _) => page('Login')),
          GoRoute(path: AppRouter.home, builder: (_, _) => page('Home')),
          GoRoute(path: AppRouter.profile, builder: (_, _) => page('Profile')),
          GoRoute(
            path: AppRouter.forgotPassword,
            builder: (_, _) => page('Forgot'),
          ),
          GoRoute(path: AppRouter.signup, builder: (_, _) => page('Sign up')),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authNotifierProvider.overrideWith(() => notifier)],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) =>
                SessionExpiryListener(child: child ?? const SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> settleToasts(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('a 401 on a signed-in page goes to login with the message', (
      tester,
    ) async {
      await pumpApp(
        tester,
        initial: const AuthState(status: AuthStatus.authenticated),
      );
      expect(find.text('Home'), findsOneWidget);

      notifier.expire();
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text(AuthNotifier.sessionExpiredMessage), findsOneWidget);

      // Later 401s from requests that were already in flight do not repeat it.
      notifier.expire();
      await tester.pump();
      expect(find.text(AuthNotifier.sessionExpiredMessage), findsOneWidget);

      await settleToasts(tester);
    });

    testWidgets('a 401 on a pushed page leaves the whole signed-in stack', (
      tester,
    ) async {
      await pumpApp(
        tester,
        initial: const AuthState(status: AuthStatus.authenticated),
      );
      router.push(AppRouter.profile);
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);

      notifier.expire();
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
      expect(find.text('Home'), findsNothing);
      expect(router.canPop(), isFalse);

      await settleToasts(tester);
    });

    testWidgets('logging out redirects without the session-expired message', (
      tester,
    ) async {
      await pumpApp(
        tester,
        initial: const AuthState(status: AuthStatus.authenticated),
      );

      await notifier.logout();
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text(AuthNotifier.sessionExpiredMessage), findsNothing);
    });

    testWidgets('does not redirect while the status is unknown', (
      tester,
    ) async {
      await pumpApp(tester, initial: const AuthState());

      expect(AppRouter.authStatus.value, AuthStatus.unknown);
      expect(find.text('Home'), findsOneWidget);

      notifier.restored();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('signed out: signed-in routes go to login, public ones open', (
      tester,
    ) async {
      await pumpApp(
        tester,
        initial: const AuthState(status: AuthStatus.unauthenticated),
        initialLocation: AppRouter.login,
      );
      expect(find.text('Login'), findsOneWidget);

      for (final path in [AppRouter.home, AppRouter.profile]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(find.text('Login'), findsOneWidget, reason: path);
      }

      router.go(AppRouter.forgotPassword);
      await tester.pumpAndSettle();
      expect(find.text('Forgot'), findsOneWidget);

      router.go(AppRouter.signup);
      await tester.pumpAndSettle();
      expect(find.text('Sign up'), findsOneWidget);
      expect(find.text(AuthNotifier.sessionExpiredMessage), findsNothing);
    });
  });

  test('every public auth page stays reachable while signed out', () {
    expect(
      AppRouter.publicPaths,
      containsAll([
        AppRouter.login,
        AppRouter.signup,
        AppRouter.magicLinkRequest,
        AppRouter.magicLinkSent,
        AppRouter.forgotPassword,
        AppRouter.resetPassword,
      ]),
    );
    for (final path in [
      AppRouter.home,
      AppRouter.profile,
      AppRouter.createOrganization,
      AppRouter.buyCredits,
    ]) {
      expect(AppRouter.publicPaths, isNot(contains(path)), reason: path);
    }
  });
}
