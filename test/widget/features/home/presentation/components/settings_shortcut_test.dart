import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _Auth extends AuthNotifier {
  _Auth(this.status);

  final AuthStatus status;

  @override
  AuthState build() => AuthState(status: status);
}

GoRouter _router({required String initial}) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: AppRouter.home,
      builder: (_, _) => const Scaffold(body: TextField(autofocus: true)),
    ),
    GoRoute(
      path: AppRouter.profile,
      builder: (_, _) => const Scaffold(body: Text('settings screen')),
    ),
  ],
);

Future<GoRouter> _pump(
  WidgetTester tester, {
  String initial = AppRouter.home,
  AuthStatus status = AuthStatus.authenticated,
}) async {
  final router = _router(initial: initial);
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [authNotifierProvider.overrideWith(() => _Auth(status))],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => SettingsShortcut(
          router: router,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _press(
  WidgetTester tester, {
  LogicalKeyboardKey modifier = LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey key = LogicalKeyboardKey.comma,
}) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  group('Ctrl+, opens Settings', () {
    testWidgets('from Home, even with a text field focused', (tester) async {
      final router = await _pump(tester);
      expect(_path(router), AppRouter.home);

      await _press(tester);

      expect(_path(router), AppRouter.profile);
      expect(find.text('settings screen'), findsOneWidget);
    });

    testWidgets('Cmd+, works too', (tester) async {
      final router = await _pump(tester);

      await _press(tester, modifier: LogicalKeyboardKey.metaLeft);

      expect(_path(router), AppRouter.profile);
    });

    testWidgets('pressing it again on Settings stays there', (tester) async {
      final router = await _pump(tester, initial: AppRouter.profile);

      await _press(tester);

      expect(_path(router), AppRouter.profile);
      expect(find.text('settings screen'), findsOneWidget);
    });

    testWidgets('a bare comma and Ctrl+period do nothing', (tester) async {
      final router = await _pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await _press(tester, key: LogicalKeyboardKey.period);

      expect(_path(router), AppRouter.home);
    });

    testWidgets('does nothing when signed out', (tester) async {
      final router = await _pump(tester, status: AuthStatus.unauthenticated);

      await _press(tester);

      expect(_path(router), AppRouter.home);
    });
  });
}
