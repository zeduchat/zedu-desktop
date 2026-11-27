import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const account = ProfileAccount(
    name: 'Ada Lovelace',
    email: 'ada@zedu.test',
    timezone: 'Africa/Lagos',
  );

  Future<List<ProfileAccount>> open(
    WidgetTester tester,
    ProfileAccount account,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    final saved = <ProfileAccount>[];
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showEditAccountDialog(context, account, saved.add),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return saved;
  }

  Finder timezoneField() => find.byKey(const ValueKey('edit-account-timezone'));

  testWidgets('offers a timezone dropdown instead of a free-text field', (
    tester,
  ) async {
    await open(tester, account);

    expect(timezoneField(), findsOneWidget);
    // Only Name and Email are free text.
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('(UTC+01:00) West Central Africa'), findsOneWidget);
  });

  testWidgets('saves the IANA id of the chosen timezone', (tester) async {
    final saved = await open(tester, account);

    await tester.tap(timezoneField());
    await tester.pumpAndSettle();
    await tester.tap(find.text('(UTC+02:00) Cairo, Helsinki, Bucharest').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved.single.timezone, 'Africa/Cairo');
    expect(find.text('Edit Account'), findsNothing);
  });

  testWidgets('keeps a saved timezone that is not in the list', (tester) async {
    final saved = await open(
      tester,
      account.copyWith(timezone: 'Africa/Accra'),
    );

    expect(find.text('Africa/Accra'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved.single.timezone, 'Africa/Accra');
  });
}
