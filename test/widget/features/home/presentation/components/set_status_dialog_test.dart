import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier([
    this._initial = const AuthState(status: AuthStatus.unauthenticated),
  ]);

  final AuthState _initial;
  StatusTimeout? savedTimeout;
  bool? savedPauseNotifications;

  @override
  AuthState build() => _initial;

  @override
  Future<bool> changeStatus({
    required String icon,
    required String text,
    required StatusTimeout timeout,
    required bool pauseNotifications,
  }) async {
    savedTimeout = timeout;
    savedPauseNotifications = pauseNotifications;
    return true;
  }
}

AuthState _signedInWith(UserStatus status) {
  return AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'me',
      firstName: 'Dave',
      lastName: 'Tolu',
      email: 'me@zedu.chat',
      phone: '',
      username: 'me',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026, 10, 16),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'org-1',
      avatarUrl: '',
      defaultAvatarUrl: '',
      status: status,
    ),
  );
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  _FakeAuthNotifier Function()? notifier,
}) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(notifier ?? _FakeAuthNotifier.new),
      ],
      child: MaterialApp(
        // The ink-sparkle shader isn't available under flutter_test.
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: const Scaffold(body: SetStatusDialog()),
      ),
    ),
  );
}

Finder _checkIcon() => find.byIcon(Icons.check_circle);

MouseCursor _activeCursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1)!;

void main() {
  group('SetStatusDialog suggested statuses', () {
    testWidgets('shows no selected suggestion initially', (tester) async {
      await _pumpDialog(tester);

      expect(_checkIcon(), findsNothing);
    });

    testWidgets('selecting a suggestion marks only that row', (tester) async {
      await _pumpDialog(tester);

      await tester.tap(find.text('In a meeting'));
      await tester.pump();

      expect(_checkIcon(), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('In a meeting'),
            matching: find.byType(Row),
          ),
          matching: _checkIcon(),
        ),
        findsOneWidget,
      );
    });

    testWidgets('selecting another suggestion moves the selection', (
      tester,
    ) async {
      await _pumpDialog(tester);

      await tester.tap(find.text('In a meeting'));
      await tester.pump();
      await tester.tap(find.text('Commuting'));
      await tester.pump();

      expect(_checkIcon(), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Commuting'),
            matching: find.byType(Row),
          ),
          matching: _checkIcon(),
        ),
        findsOneWidget,
      );
    });

    testWidgets('editing the status text clears the selection', (tester) async {
      await _pumpDialog(tester);

      await tester.tap(find.text('In a meeting'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'In a meeting now');
      await tester.pump();

      expect(_checkIcon(), findsNothing);
    });

    testWidgets('changing the expiry clears the selection', (tester) async {
      await _pumpDialog(tester);

      await tester.tap(find.text('In a meeting'));
      await tester.pump();
      await tester.tap(find.byType(DropdownButton<StatusTimeout>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This week').last);
      await tester.pumpAndSettle();

      expect(_checkIcon(), findsNothing);
    });

    testWidgets('restoring matching values reselects the suggestion', (
      tester,
    ) async {
      await _pumpDialog(tester);

      await tester.tap(find.text('In a meeting'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'In a meeting x');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'In a meeting');
      await tester.pump();

      expect(_checkIcon(), findsOneWidget);
    });

    testWidgets('displays valid emojis for preset status options', (
      tester,
    ) async {
      await _pumpDialog(tester);

      expect(find.text('📅'), findsOneWidget);
      expect(find.text('🚗'), findsOneWidget);
      expect(find.text('🤒'), findsOneWidget);
      expect(find.text('🌴'), findsOneWidget);
      expect(find.text('🏠'), findsOneWidget);
    });

    testWidgets(
      'selecting a preset updates the emoji button with the preset emoji',
      (tester) async {
        await _pumpDialog(tester);

        await tester.tap(find.text('In a meeting'));
        await tester.pump();

        expect(find.text('📅'), findsNWidgets(2));
      },
    );
  });

  group('SetStatusDialog reopened with a saved status', () {
    const vacationing = UserStatus(
      emoji: '🌴',
      text: 'Vacationing',
      pauseNotifications: true,
    );

    testWidgets('restores "Don\'t remove" and the suggestion', (tester) async {
      await _pumpDialog(
        tester,
        notifier: () => _FakeAuthNotifier(_signedInWith(vacationing)),
      );

      final dropdown = tester.widget<DropdownButton<StatusTimeout>>(
        find.byType(DropdownButton<StatusTimeout>),
      );
      expect(dropdown.value, StatusTimeout.dontRemove);
      expect(_checkIcon(), findsOneWidget);
    });

    testWidgets('restores the pause notifications tick', (tester) async {
      await _pumpDialog(
        tester,
        notifier: () => _FakeAuthNotifier(_signedInWith(vacationing)),
      );

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });

    testWidgets('keeps the default expiry for a status that expires', (
      tester,
    ) async {
      await _pumpDialog(
        tester,
        notifier: () => _FakeAuthNotifier(
          _signedInWith(
            UserStatus(
              emoji: '🚗',
              text: 'Commuting',
              expiresAt: DateTime.now().add(const Duration(minutes: 30)),
            ),
          ),
        ),
      );

      final dropdown = tester.widget<DropdownButton<StatusTimeout>>(
        find.byType(DropdownButton<StatusTimeout>),
      );
      expect(dropdown.value, StatusTimeout.thirtyMinutes);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets('saving without changes keeps the saved settings', (
      tester,
    ) async {
      final notifier = _FakeAuthNotifier(_signedInWith(vacationing));
      await _pumpDialog(tester, notifier: () => notifier);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(notifier.savedTimeout, StatusTimeout.dontRemove);
      expect(notifier.savedPauseNotifications, isTrue);
    });
  });

  group('SetStatusDialog cursors', () {
    testWidgets('clickable parts show the click cursor on hover', (
      tester,
    ) async {
      await _pumpDialog(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);

      for (final target in [
        find.text('In a meeting'),
        find.bySemanticsLabel('Choose status emoji'),
        find.text('Pause notifications'),
      ]) {
        await mouse.moveTo(tester.getCenter(target));
        await tester.pump();
        expect(_activeCursor(), SystemMouseCursors.click, reason: '$target');
      }
    });
  });
}
