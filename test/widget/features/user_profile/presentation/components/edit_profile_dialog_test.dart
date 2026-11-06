import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const account = ProfileAccount(
    name: 'Ada Lovelace',
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

  testWidgets('close button has a tooltip and dismisses without saving', (
    tester,
  ) async {
    var saved = false;
    await openDialog(tester, (_) async {
      saved = true;
      return null;
    });

    final closeButton = find.byTooltip('Close');
    expect(closeButton, findsOneWidget);

    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(saved, isFalse);
  });

  testWidgets('rejects an unsupported manually entered country', (
    tester,
  ) async {
    ProfileAccount? saved;
    await openDialog(tester, (account) async {
      saved = account;
      return null;
    });

    await tester.enterText(find.byType(TextFormField).last, 'ugggge');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Select a country from the list'), findsOneWidget);
    expect(saved, isNull);
  });

  testWidgets('passes the selected country to the save callback', (
    tester,
  ) async {
    ProfileAccount? saved;
    await openDialog(tester, (account) async {
      saved = account;
      return null;
    });

    final countryField = find.byType(TextFormField).last;
    await tester.ensureVisible(countryField);
    await tester.pumpAndSettle();
    await tester.tap(countryField);
    await tester.enterText(countryField, 'Nige');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nigeria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved?.country, 'Nigeria');
  });

  testWidgets('accepts and normalizes a typed country without selecting it', (
    tester,
  ) async {
    ProfileAccount? saved;
    await openDialog(tester, (account) async {
      saved = account;
      return null;
    });

    await tester.enterText(find.byType(TextFormField).last, 'nigeria');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Select a country from the list'), findsNothing);
    expect(saved?.country, 'Nigeria');
  });

  group('saving', () {
    Finder titleField() => find.descendant(
      of: find.widgetWithText(AppTextField, 'Title'),
      matching: find.byType(TextFormField),
    );
    Finder saveButton() => find.byType(ElevatedButton);

    testWidgets('stays open while saving and closes once it succeeds', (
      tester,
    ) async {
      final result = Completer<String?>();
      await openDialog(tester, (_) => result.future);

      await tester.tap(find.text('Save changes'));
      await tester.pump();

      expect(find.text('Edit your profile'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(saveButton()).onPressed, isNull);

      result.complete(null);
      await tester.pumpAndSettle();

      expect(find.text('Edit your profile'), findsNothing);
    });

    testWidgets('a second click while saving does not save twice', (
      tester,
    ) async {
      var calls = 0;
      final result = Completer<String?>();
      await openDialog(tester, (_) {
        calls++;
        return result.future;
      });

      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.tap(saveButton(), warnIfMissed: false);
      await tester.pump();

      expect(calls, 1);
      result.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('a failed save keeps the draft and shows the error', (
      tester,
    ) async {
      var calls = 0;
      await openDialog(tester, (_) async {
        calls++;
        return calls == 1 ? 'Network error. Please try again.' : null;
      });

      await tester.enterText(titleField(), 'Engineer');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Edit your profile'), findsOneWidget);
      expect(find.text('Network error. Please try again.'), findsOneWidget);
      expect(find.text('Engineer'), findsOneWidget);

      // The user can retry; the error clears and the dialog closes.
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('Edit your profile'), findsNothing);
    });
  });

  testWidgets('asks before canceling a changed profile', (tester) async {
    await openDialog(tester, (_) async => null);

    final nameField = find.descendant(
      of: find.widgetWithText(AppTextField, 'Full Name'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(nameField, 'Grace Hopper');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Edit your profile'), findsOneWidget);
  });

  testWidgets('asks before a barrier tap discards profile changes', (
    tester,
  ) async {
    await openDialog(tester, (_) async => null);

    final nameField = find.descendant(
      of: find.widgetWithText(AppTextField, 'Full Name'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(nameField, 'Grace Hopper');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Edit your profile'), findsOneWidget);
  });

  testWidgets('asks before the close button discards profile changes', (
    tester,
  ) async {
    await openDialog(tester, (_) async => null);

    final nameField = find.descendant(
      of: find.widgetWithText(AppTextField, 'Full Name'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(nameField, 'Grace Hopper');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Edit your profile'), findsOneWidget);
  });

  testWidgets('asks before Escape discards profile changes', (tester) async {
    await openDialog(tester, (_) async => null);

    final nameField = find.descendant(
      of: find.widgetWithText(AppTextField, 'Full Name'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(nameField, 'Grace Hopper');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Edit your profile'), findsOneWidget);
  });

  testWidgets('canceling discard keeps the changed profile open', (
    tester,
  ) async {
    await openDialog(tester, (_) async => null);

    final nameField = find.descendant(
      of: find.widgetWithText(AppTextField, 'Full Name'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(nameField, 'Grace Hopper');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final confirmation = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(of: confirmation, matching: find.text('Cancel')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit your profile'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsOneWidget);
  });

  testWidgets('confirmed discard closes the changed profile', (tester) async {
    await openDialog(tester, (_) async => null);

    final nameField = find.descendant(
      of: find.widgetWithText(AppTextField, 'Full Name'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(nameField, 'Grace Hopper');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit your profile'), findsNothing);
  });

  testWidgets('cancel closes an unchanged profile without confirmation', (
    tester,
  ) async {
    await openDialog(tester, (_) async => null);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit your profile'), findsNothing);
  });

  testWidgets('barrier tap closes an unchanged profile without confirmation', (
    tester,
  ) async {
    await openDialog(tester, (_) async => null);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit your profile'), findsNothing);
  });
}
