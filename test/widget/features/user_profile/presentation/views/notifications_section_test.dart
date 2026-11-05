import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

const _saved = NotificationPreferences(
  mode: NotificationMode.allMessages,
  quietHoursEnabled: true,
  pauseFrom: 22 * 60,
  resumeAt: 7 * 60,
  emailNotifications: false,
  differentMobileSettings: false,
  timezone: 'Africa/Lagos',
);

final _bar = find.byKey(const ValueKey('notifications-unsaved-bar'));
final _mentions = find.byKey(const ValueKey('notification-mode-mentionsOnly'));
final _allMessages = find.byKey(
  const ValueKey('notification-mode-allMessages'),
);

/// Plays the parent's role: holds the saved preferences and the saving flag,
/// and runs [save] to decide whether a save succeeds.
class _Harness extends StatefulWidget {
  const _Harness({required this.save});

  final Future<bool> Function(NotificationPreferences) save;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  NotificationPreferences _preferences = _saved;
  bool _isSaving = false;

  Future<void> _onSave(NotificationPreferences draft) async {
    setState(() => _isSaving = true);
    final ok = await widget.save(draft);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (ok) _preferences = draft;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NotificationsSection(
        preferences: _preferences,
        isSaving: _isSaving,
        onSave: _onSave,
        workspaceName: 'Heron Academy',
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Future<bool> Function(NotificationPreferences)? save,
}) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    buildTestMaterialApp(_Harness(save: save ?? (_) async => true)),
  );
}

void main() {
  group('NotificationsSection', () {
    testWidgets('shows the three modes with their explanations', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('All new messages'), findsOneWidget);
      expect(find.text('Mentions'), findsOneWidget);
      expect(find.text('Nothing'), findsOneWidget);
      expect(
        find.text('Applies to every channel and DM in Heron Academy.'),
        findsOneWidget,
      );
    });

    testWidgets('hides the unsaved bar until something changes', (
      tester,
    ) async {
      await _pump(tester);
      expect(_bar, findsNothing);

      await tester.tap(_mentions);
      await tester.pump();

      expect(_bar, findsOneWidget);
      expect(find.text('You have unsaved changes'), findsOneWidget);
    });

    testWidgets('hides the bar again when the value goes back', (tester) async {
      await _pump(tester);

      await tester.tap(_mentions);
      await tester.pump();
      await tester.tap(_allMessages);
      await tester.pump();

      expect(_bar, findsNothing);
    });

    testWidgets('revert restores the saved values without saving', (
      tester,
    ) async {
      var saves = 0;
      await _pump(
        tester,
        save: (_) async {
          saves++;
          return true;
        },
      );

      await tester.tap(_mentions);
      await tester.tap(find.text('Email notifications'));
      await tester.pump();
      await tester.tap(find.text('Revert'));
      await tester.pump();

      expect(_bar, findsNothing);
      expect(saves, 0);
      final email = tester.widget<Switch>(find.byType(Switch).at(1));
      expect(email.value, isFalse);
    });

    testWidgets('save sends the draft and hides the bar on success', (
      tester,
    ) async {
      final sent = <NotificationPreferences>[];
      await _pump(
        tester,
        save: (draft) async {
          sent.add(draft);
          return true;
        },
      );

      await tester.tap(_mentions);
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(sent.single.mode, NotificationMode.mentionsOnly);
      expect(_bar, findsNothing);
    });

    testWidgets('keeps the edits when the save fails', (tester) async {
      await _pump(tester, save: (_) async => false);

      await tester.tap(_mentions);
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(_bar, findsOneWidget);
    });

    testWidgets('does not save twice while a save is running', (tester) async {
      final pending = Completer<bool>();
      var saves = 0;
      await _pump(
        tester,
        save: (_) {
          saves++;
          return pending.future;
        },
      );

      await tester.tap(_mentions);
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.tap(find.byType(AppButton).last, warnIfMissed: false);
      await tester.pump();

      expect(saves, 1);
      pending.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('summarises quiet hours that cross midnight with timezone', (
      tester,
    ) async {
      await _pump(tester);

      expect(
        find.text(
          'Notifications paused from 10:00 PM to 7:00 AM the next day.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Times are in your profile timezone, Africa/Lagos.'),
        findsOneWidget,
      );
    });

    testWidgets('fits a narrow window without overflowing', (tester) async {
      tester.view.physicalSize = const Size(520, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        buildTestMaterialApp(_Harness(save: (_) async => true)),
      );
      await tester.tap(_mentions);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('quietHoursSummary', () {
    test('describes a same-day period', () {
      expect(
        quietHoursSummary(
          _saved.copyWith(pauseFrom: 13 * 60, resumeAt: 14 * 60),
        ),
        'Notifications paused from 1:00 PM to 2:00 PM.',
      );
    });

    test('says when quiet hours are off', () {
      expect(
        quietHoursSummary(_saved.copyWith(quietHoursEnabled: false)),
        'Quiet hours are off. Notifications can arrive at any time.',
      );
    });

    test('flags a period with no length', () {
      final empty = _saved.copyWith(pauseFrom: 9 * 60, resumeAt: 9 * 60);
      expect(empty.hasValidQuietHours, isFalse);
      expect(
        quietHoursSummary(empty),
        'Choose different pause and resume times.',
      );
    });
  });
}
