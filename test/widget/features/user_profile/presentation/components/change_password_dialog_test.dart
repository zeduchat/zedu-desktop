import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const current = 'current-password';
  const updated = 'NewPassw0rd!';
  const rejected = Failure<void>(
    ApiFailure(
      message: 'Current password is incorrect',
      kind: ApiFailureKind.client,
    ),
  );

  Future<void> openAndSubmit(
    WidgetTester tester,
    Future<Result<void>> Function({
      required String currentPassword,
      required String newPassword,
    })
    onSave,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showChangePasswordDialog(context, onSave),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), updated);
    await tester.enterText(fields.at(2), updated);
    await tester.pump();
    await tester.tap(find.text('Update Password'));
    await tester.pump();
  }

  testWidgets('stays open with a spinner while the request runs', (
    tester,
  ) async {
    final response = Completer<Result<void>>();
    await openAndSubmit(
      tester,
      ({required currentPassword, required newPassword}) => response.future,
    );

    expect(find.text('Change password'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Neither Cancel nor the barrier can close it mid-request.
    await tester.tap(find.text('Cancel'), warnIfMissed: false);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.text('Change password'), findsOneWidget);

    response.complete(const Success(null));
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsNothing);
  });

  testWidgets('shows a failure in the dialog and keeps the typed values', (
    tester,
  ) async {
    await openAndSubmit(
      tester,
      ({required currentPassword, required newPassword}) async => rejected,
    );
    await tester.pumpAndSettle();

    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Current password is incorrect'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final values = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((field) => field.controller.text);
    expect(values, [current, updated, updated]);
  });

  testWidgets('a retry clears the error and closes on success', (tester) async {
    var calls = 0;
    await openAndSubmit(tester, ({
      required currentPassword,
      required newPassword,
    }) async {
      calls++;
      return calls == 1 ? rejected : const Success<void>(null);
    });
    await tester.pumpAndSettle();
    expect(find.text('Current password is incorrect'), findsOneWidget);

    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Change password'), findsNothing);
  });

  testWidgets('sends the typed passwords', (tester) async {
    String? sentCurrent;
    String? sentNew;
    await openAndSubmit(tester, ({
      required currentPassword,
      required newPassword,
    }) async {
      sentCurrent = currentPassword;
      sentNew = newPassword;
      return const Success<void>(null);
    });
    await tester.pumpAndSettle();

    expect(sentCurrent, current);
    expect(sentNew, updated);
    expect(find.text('Change password'), findsNothing);
  });
}
