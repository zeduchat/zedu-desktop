import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

void main() {
  Future<void> openMenu(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_TestAuthNotifier.new),
          orgCreditBalanceProvider.overrideWith((ref) => 0),
        ],
        child: buildTestMaterialApp(
          const Scaffold(
            body: Stack(
              children: [
                Positioned(left: 0, bottom: 16, child: UserMenuButton()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(UserMenuButton));
    await tester.pumpAndSettle();
  }

  testWidgets('aligns the menu to the rail without dimming the workspace', (
    tester,
  ) async {
    await openMenu(tester, const Size(1200, 800));

    final card = tester.getRect(find.byKey(const ValueKey('user-menu-card')));
    expect(card.left, AppSidebarRail.width);
    expect(card.width, 300);
    expect(card.right, AppSidebarRail.width + 300);

    final menuBarrierFinder = find.byWidgetPredicate(
      (widget) =>
          widget is ModalBarrier && widget.dismissible && widget.color == null,
      description: 'the unpainted, dismissible modal barrier for the user menu',
    );
    expect(menuBarrierFinder, findsOneWidget);
    final barrier = tester.widget<ModalBarrier>(menuBarrierFinder);
    // Flutter omits the barrier color when the route color is fully transparent.
    expect(barrier.color, isNull);
    expect(barrier.dismissible, isTrue);
    expect(find.text('Update your status'), findsOneWidget);
    expect(find.text('Pause notifications'), findsOneWidget);
    expect(find.text('Sign out of Zedu'), findsOneWidget);
  });

  testWidgets('shrinks the menu to fit a narrower desktop window', (
    tester,
  ) async {
    await openMenu(tester, const Size(340, 700));

    final card = tester.getRect(find.byKey(const ValueKey('user-menu-card')));
    expect(card.left, AppSidebarRail.width);
    expect(card.width, 274);
    expect(card.right, lessThanOrEqualTo(324));
  });
}
