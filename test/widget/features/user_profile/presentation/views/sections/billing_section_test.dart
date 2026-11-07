import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  testWidgets('Invite People opens the invite dialog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Scaffold(
            body: BillingSection(
              billing: BillingInfo.empty(),
              onInvite: ({required email, required role}) async {},
              onComparePlans: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Invite People'));
    await tester.pumpAndSettle();

    expect(find.text('Invite Team Member'), findsOneWidget);
  });

  testWidgets('Displays billing plan from billing model', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Scaffold(
            body: BillingSection(
              billing: BillingInfo(
                plan: 'Zedu Pro',
                description: 'Monthly subscription with all features',
                paymentHistory: const [],
              ),
              onInvite: ({required email, required role}) async {},
              onComparePlans: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Zedu Pro'), findsOneWidget);
    expect(find.text('Monthly subscription with all features'), findsOneWidget);
  });

  testWidgets('Displays payment history entries', (tester) async {
    final records = [
      PaymentRecord(
        id: 'rec1',
        description: 'Monthly subscription payment',
        amount: '\$19.99',
        date: '2024-01-15',
        status: 'completed',
      ),
      PaymentRecord(
        id: 'rec2',
        description: 'Annual plan upgrade payment',
        amount: '\$199.99',
        date: '2024-02-01',
        status: 'pending',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Scaffold(
            body: BillingSection(
              billing: BillingInfo(
                plan: 'Zedu Pro',
                description: 'Premium monthly plan',
                paymentHistory: records,
              ),
              onInvite: ({required email, required role}) async {},
              onComparePlans: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Zedu Pro'), findsOneWidget);
    expect(find.text('Premium monthly plan'), findsOneWidget);
    expect(find.text('\$19.99'), findsOneWidget);
    expect(find.text('2024-01-15'), findsOneWidget);
    expect(find.text('\$199.99'), findsOneWidget);
    expect(find.text('2024-02-01'), findsOneWidget);
  });

  testWidgets('Shows empty payment history state when no records', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Scaffold(
            body: BillingSection(
              billing: BillingInfo.empty(),
              onInvite: ({required email, required role}) async {},
              onComparePlans: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('No payment history found.'), findsOneWidget);
    expect(
      find.textContaining('Your payment and transaction history'),
      findsOneWidget,
    );
  });

  testWidgets('Compare Plans opens the plan comparison flow', (tester) async {
    var comparePlansOpened = false;

    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Scaffold(
            body: BillingSection(
              billing: BillingInfo.empty(),
              onInvite: ({required email, required role}) async {},
              onComparePlans: () => comparePlansOpened = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Compare Plans'));

    expect(comparePlansOpened, isTrue);
  });

  testWidgets('billing actions remain visible at a narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(540, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Scaffold(
            body: BillingSection(
              billing: BillingInfo.empty(),
              onInvite: ({required email, required role}) async {},
              onComparePlans: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Invite People'), findsOneWidget);
    expect(find.text('Compare Plans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
