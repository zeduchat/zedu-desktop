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
      builder: (_, _) => const Scaffold(body: Text('home screen')),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const Scaffold(body: TextField(autofocus: true)),
    ),
  ],
);

Future<(ProviderContainer, GoRouter)> _pump(
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
        builder: (context, child) => RailNumberShortcuts(
          router: router,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, router);
}

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey digit, {
  LogicalKeyboardKey modifier = LogicalKeyboardKey.controlLeft,
}) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(digit);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  group('Ctrl+1 to Ctrl+4', () {
    testWidgets('open Home, DMs, People and Files in rail order', (
      tester,
    ) async {
      final (container, _) = await _pump(tester);
      HomeSidebarType type() => container.read(homeSidebarProvider);

      await _press(tester, LogicalKeyboardKey.digit2);
      expect(type(), HomeSidebarType.dms);

      await _press(tester, LogicalKeyboardKey.digit3);
      expect(type(), HomeSidebarType.people);

      await _press(tester, LogicalKeyboardKey.digit4);
      expect(type(), HomeSidebarType.files);

      await _press(tester, LogicalKeyboardKey.digit1);
      expect(type(), HomeSidebarType.home);
    });

    testWidgets('Cmd+number works too', (tester) async {
      final (container, _) = await _pump(tester);

      await _press(
        tester,
        LogicalKeyboardKey.digit3,
        modifier: LogicalKeyboardKey.metaLeft,
      );

      expect(container.read(homeSidebarProvider), HomeSidebarType.people);
    });

    testWidgets('from another screen they go to Home first, with a text '
        'field focused', (tester) async {
      final (container, router) = await _pump(tester, initial: '/settings');
      expect(_path(router), '/settings');

      await _press(tester, LogicalKeyboardKey.digit2);

      expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
      expect(_path(router), AppRouter.home);
    });

    testWidgets('Ctrl+5 and a bare number do nothing', (tester) async {
      final (container, _) = await _pump(tester);

      await _press(tester, LogicalKeyboardKey.digit5);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();

      expect(container.read(homeSidebarProvider), HomeSidebarType.home);
    });

    testWidgets('do nothing when signed out', (tester) async {
      final (container, router) = await _pump(
        tester,
        initial: '/settings',
        status: AuthStatus.unauthenticated,
      );

      await _press(tester, LogicalKeyboardKey.digit2);

      expect(container.read(homeSidebarProvider), HomeSidebarType.home);
      expect(_path(router), '/settings');
    });
  });
}
