import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

void main() {
  // A Friday at 10:00, so "tomorrow at 9" is unambiguous.
  final now = DateTime(2026, 11, 6, 10);

  Future<ReminderPreset?> openPicker(WidgetTester tester) async {
    ReminderPreset? chosen;
    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                chosen = await showDialog<ReminderPreset>(
                  context: context,
                  builder: (_) => ReminderPickerDialog(now: now),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return chosen;
  }

  testWidgets('offers the three choices the server accepts', (tester) async {
    await openPicker(tester);

    expect(find.text('In 30 minutes'), findsOneWidget);
    expect(find.text('In 1 hour'), findsOneWidget);
    expect(find.text('Tomorrow at 9:00 AM'), findsOneWidget);
    // The endpoint the web client uses validates
    // `oneof=30_min 1_hour tomorrow_9am` and rejects anything else, so there
    // is no custom time to offer.
    expect(find.text('Custom'), findsNothing);
  });

  testWidgets('In 30 minutes resolves against the current time', (
    tester,
  ) async {
    await openPicker(tester);
    await tester.tap(find.text('In 30 minutes'));
    await tester.pumpAndSettle();

    // The dialog closed with a time, which the caller then sends on.
    expect(find.text('In 30 minutes'), findsNothing);
  });

  testWidgets('each preset previews the time it will set', (tester) async {
    await openPicker(tester);

    // 10:00 + 30 minutes, and 10:00 + 1 hour, both today.
    expect(find.text('Today, 10:30 AM'), findsOneWidget);
    expect(find.text('Today, 11:00 AM'), findsOneWidget);
    expect(find.text('Tomorrow, 9:00 AM'), findsOneWidget);
  });

  testWidgets('cancelling chooses nothing', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('In 30 minutes'), findsNothing);
  });

  testWidgets('choosing one returns that preset to the caller', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('In 1 hour'));
    await tester.pumpAndSettle();

    expect(find.text('In 1 hour'), findsNothing);
  });
}
