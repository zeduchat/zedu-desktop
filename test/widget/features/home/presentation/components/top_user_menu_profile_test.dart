import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated);
}

GoRouter _router(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: AppRouter.home,
      builder: (_, _) => const Scaffold(
        body: Column(
          children: [
            Text('home screen'),
            TopUserMenu(userName: 'Test User'),
          ],
        ),
      ),
    ),
    GoRoute(
      path: AppRouter.profile,
      builder: (_, _) =>
          const Scaffold(body: TopUserMenu(userName: 'Test User')),
    ),
    GoRoute(
      path: AppRouter.buyCredits,
      builder: (_, _) =>
          const Scaffold(body: TopUserMenu(userName: 'Test User')),
    ),
  ],
);

Future<ProviderContainer> _pumpMenu(
  WidgetTester tester,
  String initialLocation,
) async {
  final router = _router(initialLocation);
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(_Auth.new),
      orgCreditBalanceProvider.overrideWithValue(3),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tapProfile(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Profile'));
  await tester.pumpAndSettle();
}

void main() {
  for (final path in [AppRouter.profile, AppRouter.buyCredits]) {
    testWidgets('Profile opens the panel from $path', (tester) async {
      final container = await _pumpMenu(tester, path);

      await _tapProfile(tester);

      expect(find.text('home screen'), findsOneWidget);
      expect(container.read(personalProfilePanelProvider), isTrue);
    });
  }

  testWidgets('Profile opens the panel without leaving Home', (tester) async {
    final container = await _pumpMenu(tester, AppRouter.home);

    await _tapProfile(tester);

    expect(find.text('home screen'), findsOneWidget);
    expect(container.read(personalProfilePanelProvider), isTrue);
  });
}
