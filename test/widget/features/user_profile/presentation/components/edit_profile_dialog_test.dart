import 'dart:async';

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

  Future<void> openDialog(
    WidgetTester tester,
    EditProfileSave onSave, [
    ProfileAccount initialAccount = account,
  ]) async {
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
                  showEditProfileDialog(context, initialAccount, onSave),
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
    await tester.tap(countryField);
    await tester.enterText(countryField, 'Nige');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nigeria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved?.country, 'Nigeria');
  });

  testWidgets('highlights the country selected with the keyboard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openDialog(tester, (_) async => null);

    final countryField = find.byType(TextFormField).last;
    await tester.ensureVisible(countryField);
    await tester.tap(countryField);
    await tester.enterText(countryField, 'United');
    await tester.pumpAndSettle();

    Color optionColor(String country) {
      final coloredBox = find
          .ancestor(of: find.text(country), matching: find.byType(ColoredBox))
          .first;
      return tester.widget<ColoredBox>(coloredBox).color;
    }

    bool optionIsSelected(String country) {
      final selectedSemantics = find
          .ancestor(
            of: find.text(country),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.selected != null,
            ),
          )
          .first;
      return tester.widget<Semantics>(selectedSemantics).properties.selected ??
          false;
    }

    expect(optionColor('United Arab Emirates'), AppPalette.light.primaryBg);
    expect(optionIsSelected('United Arab Emirates'), isTrue);
    expect(optionIsSelected('United Kingdom'), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(optionColor('United Arab Emirates'), Colors.transparent);
    expect(optionIsSelected('United Arab Emirates'), isFalse);
    expect(optionColor('United Kingdom'), AppPalette.light.primaryBg);
    expect(optionIsSelected('United Kingdom'), isTrue);
    semantics.dispose();
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

  testWidgets('displays the friendly label for the saved IANA timezone', (
    tester,
  ) async {
    await openDialog(tester, (_) async => null);

    expect(find.text('(UTC+01:00) West Central Africa'), findsOneWidget);
  });

  testWidgets(
    'preserves existing valid IANA value when saved without changing timezone',
    (tester) async {
      ProfileAccount? saved;
      await openDialog(tester, (account) async {
        saved = account;
        return null;
      });

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(saved?.timezone, 'Africa/Lagos');
    },
  );

  testWidgets(
    'selecting a timezone persists an IANA identifier, not the dropdown label',
    (tester) async {
      ProfileAccount? saved;
      await openDialog(tester, (account) async {
        saved = account;
        return null;
      });

      final timezoneDropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(timezoneDropdown);
      await tester.pumpAndSettle();
      await tester.tap(timezoneDropdown);
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('(UTC+00:00) London, Dublin, Lisbon').last,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(saved?.timezone, 'Europe/London');
    },
  );

  testWidgets(
    'maps an older saved display label to its IANA identifier on save',
    (tester) async {
      ProfileAccount? saved;
      await openDialog(tester, (account) async {
        saved = account;
        return null;
      }, account.copyWith(timezone: '(UTC+01:00) West Central Africa'));

      expect(find.text('(UTC+01:00) West Central Africa'), findsOneWidget);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(saved?.timezone, 'Africa/Lagos');
    },
  );

  testWidgets('preserves an unknown IANA timezone if the account has one', (
    tester,
  ) async {
    ProfileAccount? saved;
    await openDialog(tester, (account) async {
      saved = account;
      return null;
    }, account.copyWith(timezone: 'Africa/Accra'));

    expect(find.text('Africa/Accra'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved?.timezone, 'Africa/Accra');
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

  group('discarding edits', () {
    testWidgets('Cancel on a changed form asks before discarding', (
      tester,
    ) async {
      await openDialog(tester, (_) async => null);

      await tester.enterText(find.byType(TextFormField).first, 'Ada B');
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The form is still up, with a question on top of it.
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Edit your profile'), findsOneWidget);

      // Keeping the edits drops the question and leaves the typing in place.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit your profile'), findsOneWidget);
      expect(find.text('Ada B'), findsOneWidget);

      // Discarding then closes it.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Edit your profile'), findsNothing);
    });

    testWidgets('Cancel on an unchanged form closes straight away', (
      tester,
    ) async {
      await openDialog(tester, (_) async => null);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit your profile'), findsNothing);
    });

    testWidgets('the header close button asks too', (tester) async {
      await openDialog(tester, (_) async => null);

      await tester.enterText(find.byType(TextFormField).first, 'Changed');
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Edit your profile'), findsOneWidget);
    });

    testWidgets('a scrim tap asks before discarding', (tester) async {
      await openDialog(tester, (_) async => null);

      await tester.enterText(find.byType(TextFormField).first, 'Changed');
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Edit your profile'), findsOneWidget);
    });

    testWidgets('a scrim tap still closes an unchanged form', (tester) async {
      await openDialog(tester, (_) async => null);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit your profile'), findsNothing);
    });
  });
}
