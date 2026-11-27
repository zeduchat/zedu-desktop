import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const account = ProfileAccount(
    name: 'Ada Lovelace',
    username: 'ada',
    email: 'ada@example.com',
    timezone: 'Africa/Lagos',
  );

  Future<void> openDialog(WidgetTester tester, EditProfileSave onSave) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showEditProfileDialog(context, account, onSave),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('username validation', () {
    Finder usernameField() => find.descendant(
      of: find.widgetWithText(AppTextField, 'Username'),
      matching: find.byType(TextFormField),
    );

    for (final entry in {'empty': '', 'whitespace-only': '   '}.entries) {
      testWidgets('rejects ${entry.key} usernames without saving', (
        tester,
      ) async {
        ProfileAccount? saved;
        await openDialog(tester, (account, _) async {
          saved = account;
          return null;
        });

        await tester.enterText(usernameField(), entry.value);
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();

        expect(find.text('Username is required'), findsOneWidget);
        expect(saved, isNull);
        expect(find.byType(Dialog), findsOneWidget);
      });
    }

    testWidgets(
      'saves a nonempty username with surrounding whitespace trimmed',
      (tester) async {
        ProfileAccount? saved;
        await openDialog(tester, (account, _) async {
          saved = account;
          return null;
        });

        await tester.enterText(usernameField(), '  newname  ');
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();

        expect(saved?.username, 'newname');
        expect(find.byType(Dialog), findsNothing);
      },
    );
  });
}
