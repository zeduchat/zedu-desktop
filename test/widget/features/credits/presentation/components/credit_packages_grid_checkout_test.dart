import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockCreditsRepository extends Mock implements CreditsRepository {}

void main() {
  for (final fails in [false, true]) {
    testWidgets(
      'disable all checkout controls until ${fails ? 'failure' : 'success'}',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1460);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = MockCreditsRepository();
        final pending = Completer<Result<CreditCheckoutSession>>();
        when(
          () => repository.purchaseCredits(
            packageId: any(named: 'packageId'),
            planId: any(named: 'planId'),
            email: 'tester@example.com',
          ),
        ).thenAnswer((_) => pending.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              creditsRepositoryProvider.overrideWithValue(repository),
            ],
            child: buildTestMaterialApp(
              Scaffold(
                body: Consumer(
                  builder: (context, ref, child) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: CreditPackagesGrid(
                      packages: const [],
                      currentPlanSlug: 'free',
                      purchasingPackageId: ref
                          .watch(creditsNotifierProvider)
                          .purchasingPackageId,
                      onPurchase: (package) {
                        unawaited(
                          ref
                              .read(creditsNotifierProvider.notifier)
                              .purchasePackage(
                                package: package,
                                email: 'tester@example.com',
                              ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final buttons = find.byType(FilledButton);
        final pro = find.widgetWithText(FilledButton, 'Upgrade to Zedu Pro');
        final business = find.widgetWithText(
          FilledButton,
          'Upgrade to Zedu Business',
        );
        expect(buttons, findsNWidgets(4));
        expect(
          tester.widgetList<FilledButton>(buttons).map((b) => b.onPressed),
          everyElement(isNotNull),
        );

        await tester.tap(pro);
        await tester.pump();

        expect(
          tester.widgetList<FilledButton>(buttons).map((b) => b.onPressed),
          everyElement(isNull),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final selectedCard = find.byWidgetPredicate(
          (widget) => widget is CreditPackageCard && widget.package.id == 'pro',
        );
        expect(
          find.descendant(
            of: selectedCard,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        await tester.tap(business);
        verify(
          () => repository.purchaseCredits(
            packageId: 'pro',
            planId: 'pro',
            email: 'tester@example.com',
          ),
        ).called(1);
        verifyNoMoreInteractions(repository);

        pending.complete(
          fails
              ? const Failure(ApiFailure(message: 'Checkout unavailable'))
              : const Success(
                  CreditCheckoutSession(
                    checkoutSessionId: 'session',
                    checkoutSessionUrl: 'https://example.invalid/checkout',
                  ),
                ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          tester.widgetList<FilledButton>(buttons).map((b) => b.onPressed),
          everyElement(isNotNull),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
