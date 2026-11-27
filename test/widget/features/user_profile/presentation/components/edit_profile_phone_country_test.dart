import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const account = ProfileAccount(
    name: 'Ada Lovelace',
    username: 'ada',
    email: 'ada@example.com',
    timezone: 'Africa/Lagos',
  );

  Future<void> openDialog(WidgetTester tester, ProfileAccount account) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showEditProfileDialog(context, account, (_) async => null),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder phoneField() => find.ancestor(
    of: find.byKey(const ValueKey('phone-country-prefix')),
    matching: find.byType(TextField),
  );

  String phoneText(WidgetTester tester) =>
      tester.widget<TextField>(phoneField()).controller!.text;

  testWidgets('shows a neutral example number', (tester) async {
    await openDialog(tester, account);

    expect(find.text('801 234 5678'), findsOneWidget);
    expect(find.textContaining('+1 234'), findsNothing);
  });

  testWidgets('choosing a country writes its dial code into the field', (
    tester,
  ) async {
    await openDialog(tester, account);

    await tester.tap(find.byKey(const ValueKey('phone-country-prefix')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('phone-country-search')),
      'Nigeria',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Nigeria'));
    await tester.pumpAndSettle();

    expect(phoneText(tester), startsWith('+234'));
    expect(find.text('NG +234'), findsOneWidget);
  });

  testWidgets('keeps a saved number as it is and shows its country', (
    tester,
  ) async {
    await openDialog(tester, account.copyWith(phoneNumber: '+447911123456'));

    expect(phoneText(tester), '+447911123456');
    expect(find.text('GB +44'), findsOneWidget);
  });

  testWidgets('replaces the code of a saved number', (tester) async {
    await openDialog(tester, account.copyWith(phoneNumber: '+447911123456'));

    await tester.tap(find.byKey(const ValueKey('phone-country-prefix')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('phone-country-search')),
      '234',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Nigeria'));
    await tester.pumpAndSettle();

    expect(phoneText(tester), '+234 7911123456');
  });
}
