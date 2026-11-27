import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAppLinks extends Mock implements AppLinks {}

class FakeDeepLinkAuthNotifier extends AuthNotifier {
  FakeDeepLinkAuthNotifier({
    this.onVerify,
    this.onLogout,
    this.authenticated = false,
    this.initialState = const AuthState(status: AuthStatus.unauthenticated),
  });

  final void Function(String token)? onVerify;
  final VoidCallback? onLogout;
  final bool authenticated;
  final AuthState initialState;

  @override
  AuthState build() => initialState;

  @override
  Future<void> verifyMagicLink({required String token}) async {
    onVerify?.call(token);
    state = authenticated
        ? const AuthState(status: AuthStatus.authenticated)
        : const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  Future<void> logout() async {
    onLogout?.call();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Lets a test finish a session restore that was still in progress.
  void finishRestore(AuthState next) => state = next;
}

final _signedInUser = User(
  id: 'user-a',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  phone: '',
  username: 'ada',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'org-1',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

final _signedIn = AuthState(
  status: AuthStatus.authenticated,
  user: _signedInUser,
);

/// Mounts the listener where App.build mounts it: in MaterialApp.router's
/// builder, above the Navigator.
Future<void> _pumpRoutedListener(
  WidgetTester tester, {
  required MockAppLinks appLinks,
  required FakeDeepLinkAuthNotifier notifier,
}) async {
  final router = GoRouter(
    initialLocation: AppRouter.home,
    navigatorKey: AppRouter.navigatorKey,
    routes: [
      GoRoute(
        path: AppRouter.login,
        builder: (context, state) => const Scaffold(body: Text('Login screen')),
      ),
      GoRoute(
        path: AppRouter.home,
        builder: (context, state) => const Scaffold(body: Text('Home screen')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authNotifierProvider.overrideWith(() => notifier)],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => AuthDeepLinkListener(
          appLinks: appLinks,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('AuthDeepLinkListener', () {
    late MockAppLinks mockAppLinks;
    late StreamController<Uri> linkController;

    setUp(() {
      locator.registerSingleton<AppConfig>(
        const AppConfig(
          apiBaseUrl: 'https://api.zedu.chat/api/v1/',
          usesMockData: false,
        ),
      );
      mockAppLinks = MockAppLinks();
      linkController = StreamController<Uri>.broadcast();

      when(
        () => mockAppLinks.uriLinkStream,
      ).thenAnswer((_) => linkController.stream);
    });

    tearDown(() async {
      await linkController.close();
      await locator.reset();
    });

    testWidgets(
      'ignores a magic link from an untrusted web host (Ziki #2482)',
      (tester) async {
        final verified = <String>[];
        when(() => mockAppLinks.getInitialLink()).thenAnswer(
          (_) async => Uri.parse(
            'https://attacker.example/auth/magick-link/verify?token=t-evil',
          ),
        );
        await _pumpRoutedListener(
          tester,
          appLinks: mockAppLinks,
          notifier: FakeDeepLinkAuthNotifier(onVerify: verified.add),
        );

        linkController.add(
          Uri.parse('https://evilzedu.chat/auth/magick-link/verify?token=t-2'),
        );
        await tester.pumpAndSettle();

        expect(verified, isEmpty);
      },
    );

    testWidgets('verifies a magic link from the trusted web host', (
      tester,
    ) async {
      final verified = <String>[];
      when(() => mockAppLinks.getInitialLink()).thenAnswer(
        (_) async =>
            Uri.parse('https://zedu.chat/auth/magick-link/verify?token=t-ok'),
      );
      await _pumpRoutedListener(
        tester,
        appLinks: mockAppLinks,
        notifier: FakeDeepLinkAuthNotifier(onVerify: verified.add),
      );
      await tester.pumpAndSettle();

      expect(verified, ['t-ok']);
    });

    testWidgets('ignores link when token query param is missing', (
      tester,
    ) async {
      String? capturedToken;

      when(
        () => mockAppLinks.getInitialLink(),
      ).thenAnswer((_) async => Uri.parse('zedu://auth/magick-link/verify'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeDeepLinkAuthNotifier(
                onVerify: (token) => capturedToken = token,
              ),
            ),
          ],
          child: MaterialApp(
            home: AuthDeepLinkListener(
              appLinks: mockAppLinks,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(capturedToken, isNull);
    });

    testWidgets('passes token to verifyMagicLink for valid initial link', (
      tester,
    ) async {
      String? capturedToken;

      when(() => mockAppLinks.getInitialLink()).thenAnswer(
        (_) async => Uri.parse('zedu://auth/magick-link/verify?token=t-123'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeDeepLinkAuthNotifier(
                onVerify: (token) => capturedToken = token,
              ),
            ),
          ],
          child: MaterialApp(
            home: AuthDeepLinkListener(
              appLinks: mockAppLinks,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(capturedToken, 't-123');
    });

    testWidgets('a successful verification reaches the user', (tester) async {
      // Mounts the listener exactly where App.build mounts it: wrapping the
      // router from MaterialApp.router's builder, above the Navigator.
      final router = GoRouter(
        initialLocation: AppRouter.login,
        navigatorKey: AppRouter.navigatorKey,
        routes: [
          GoRoute(
            path: AppRouter.login,
            builder: (context, state) =>
                const Scaffold(body: Text('Login screen')),
          ),
          GoRoute(
            path: AppRouter.home,
            builder: (context, state) =>
                const Scaffold(body: Text('Home screen')),
          ),
        ],
      );

      when(() => mockAppLinks.getInitialLink()).thenAnswer(
        (_) async => Uri.parse('zedu://auth/magick-link/verify?token=t-1'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeDeepLinkAuthNotifier(authenticated: true),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => AuthDeepLinkListener(
              appLinks: mockAppLinks,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Home screen'), findsOneWidget);
      expect(find.text('Logged in successfully!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    group('while signed in (Ziki #2619)', () {
      setUp(() {
        when(() => mockAppLinks.getInitialLink()).thenAnswer((_) async => null);
      });

      testWidgets('asks before switching accounts and does nothing yet', (
        tester,
      ) async {
        final verified = <String>[];
        var loggedOut = false;
        await _pumpRoutedListener(
          tester,
          appLinks: mockAppLinks,
          notifier: FakeDeepLinkAuthNotifier(
            initialState: _signedIn,
            onVerify: verified.add,
            onLogout: () => loggedOut = true,
          ),
        );

        linkController.add(
          Uri.parse('zedu://auth/magick-link/verify?token=t-b'),
        );
        await tester.pumpAndSettle();

        expect(verified, isEmpty);
        expect(loggedOut, isFalse);
        expect(find.textContaining('ada@example.com'), findsOneWidget);
      });

      testWidgets('Cancel keeps the current account', (tester) async {
        final verified = <String>[];
        var loggedOut = false;
        await _pumpRoutedListener(
          tester,
          appLinks: mockAppLinks,
          notifier: FakeDeepLinkAuthNotifier(
            initialState: _signedIn,
            onVerify: verified.add,
            onLogout: () => loggedOut = true,
          ),
        );

        linkController.add(
          Uri.parse('zedu://auth/magick-link/verify?token=t-b'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(verified, isEmpty);
        expect(loggedOut, isFalse);
        expect(find.text('Home screen'), findsOneWidget);
      });

      testWidgets('confirming signs out, then uses the link', (tester) async {
        final calls = <String>[];
        await _pumpRoutedListener(
          tester,
          appLinks: mockAppLinks,
          notifier: FakeDeepLinkAuthNotifier(
            initialState: _signedIn,
            authenticated: true,
            onVerify: (token) => calls.add('verify $token'),
            onLogout: () => calls.add('logout'),
          ),
        );

        linkController.add(
          Uri.parse('zedu://auth/magick-link/verify?token=t-b'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sign out and continue'));
        await tester.pumpAndSettle();

        expect(calls, ['logout', 'verify t-b']);
        expect(find.text('Logged in successfully!'), findsOneWidget);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      });

      testWidgets(
        'a link that opens the app while the session is restoring waits '
        'for it and asks',
        (tester) async {
          final verified = <String>[];
          when(() => mockAppLinks.getInitialLink()).thenAnswer(
            (_) async => Uri.parse('zedu://auth/magick-link/verify?token=t-b'),
          );
          final notifier = FakeDeepLinkAuthNotifier(
            initialState: const AuthState(status: AuthStatus.unknown),
            onVerify: verified.add,
          );
          await _pumpRoutedListener(
            tester,
            appLinks: mockAppLinks,
            notifier: notifier,
          );
          await tester.pump();
          expect(verified, isEmpty);

          notifier.finishRestore(_signedIn);
          await tester.pumpAndSettle();

          expect(verified, isEmpty);
          expect(find.textContaining('ada@example.com'), findsOneWidget);
        },
      );
    });
  });
}
