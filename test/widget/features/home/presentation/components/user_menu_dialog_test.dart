import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

// Fake notifier that avoids GetIt/locator setup while remaining
// type-compatible with authNotifierProvider.
class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier({
    required AuthState initial,
    this.toggleSucceeds = true,
    this.alwaysSkips = false,
    Completer<void>? gate,
  }) : _initial = initial,
       _gate = gate;

  final AuthState _initial;
  final bool toggleSucceeds;
  final bool alwaysSkips;
  final Completer<void>? _gate;
  int toggleCalls = 0;

  @override
  AuthState build() => _initial;

  @override
  Future<PresenceToggleResult> toggleOnlineStatus() async {
    toggleCalls++;
    if (alwaysSkips) {
      return const PresenceSkipped();
    }
    if (_gate != null) {
      await _gate.future;
    }
    if (!toggleSucceeds) {
      state = state.copyWith(error: 'Failed to update user profile');
      return const PresenceFailed('Failed to update user profile');
    }
    final user = state.user;
    if (user != null) {
      state = state.copyWith(user: _withOnline(user, !user.status.online));
    }
    return const PresenceConfirmed();
  }
}

User _withOnline(User user, bool online) => User(
  id: user.id,
  firstName: user.firstName,
  lastName: user.lastName,
  email: user.email,
  phone: user.phone,
  username: user.username,
  isVerified: user.isVerified,
  isOnboarded: user.isOnboarded,
  createdAt: user.createdAt,
  currentOrg: user.currentOrg,
  currentOrganisationSlug: user.currentOrganisationSlug,
  avatarUrl: user.avatarUrl,
  defaultAvatarUrl: user.defaultAvatarUrl,
  creditBalance: user.creditBalance,
  subscriptionPlanId: user.subscriptionPlanId,
  aiCreditsPurchasable: user.aiCreditsPurchasable,
  status: user.status.copyWith(online: online),
);

User _buildUser({bool online = true}) => User(
  id: 'user-1',
  firstName: 'Test',
  lastName: 'User',
  email: 'test@example.com',
  phone: '+1234567890',
  username: 'testuser',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026, 1, 1),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'test-org',
  avatarUrl: '',
  defaultAvatarUrl: '',
  status: UserStatus(online: online),
);

/// Hosts the dialog the same way the sidebar rail opens it (showDialog), so
/// popping the menu leaves the app tree mounted for the error toast.
Widget buildHost(FakeAuthNotifier notifier) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => notifier),
      orgCreditBalanceProvider.overrideWithValue(0),
    ],
    child: buildTestMaterialApp(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const UserMenuDialog(),
              ),
              child: const Text('open menu'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> pumpOpenMenu(
  WidgetTester tester,
  FakeAuthNotifier notifier,
) async {
  await tester.pumpWidget(buildHost(notifier));
  await tester.pump();
  await tester.tap(find.text('open menu'));
  await tester.pumpAndSettle();
}

AuthState readAuthState(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold));
  return ProviderScope.containerOf(context).read(authNotifierProvider);
}

void main() {
  group('UserMenuDialog presence toggle', () {
    testWidgets('shows Active presence with an away action while online', (
      tester,
    ) async {
      await pumpOpenMenu(
        tester,
        FakeAuthNotifier(
          initial: AuthState(
            status: AuthStatus.authenticated,
            user: _buildUser(online: true),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Set yourself as away'), findsOneWidget);
      expect(find.byType(PresenceDot), findsOneWidget);
    });

    testWidgets('shows Away presence with an active action while away', (
      tester,
    ) async {
      await pumpOpenMenu(
        tester,
        FakeAuthNotifier(
          initial: AuthState(
            status: AuthStatus.authenticated,
            user: _buildUser(online: false),
          ),
        ),
      );

      expect(find.text('Away'), findsOneWidget);
      expect(find.text('Set yourself as active'), findsOneWidget);
    });

    testWidgets('confirms the toggle and flips the presence on success', (
      tester,
    ) async {
      final notifier = FakeAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: _buildUser(online: true),
        ),
      );
      await pumpOpenMenu(tester, notifier);

      await tester.tap(find.text('Set yourself as away'));
      await tester.pumpAndSettle();

      expect(notifier.toggleCalls, 1);
      // The menu closes and the confirmed state is away.
      expect(find.text('Set yourself as away'), findsNothing);
      expect(readAuthState(tester).user?.status.online, isFalse);
    });

    testWidgets(
      'shows an error toast when the toggle fails and keeps presence',
      (tester) async {
        final notifier = FakeAuthNotifier(
          initial: AuthState(
            status: AuthStatus.authenticated,
            user: _buildUser(online: true),
          ),
          toggleSucceeds: false,
        );
        await pumpOpenMenu(tester, notifier);

        await tester.tap(find.text('Set yourself as away'));
        await tester.pumpAndSettle();

        expect(notifier.toggleCalls, 1);
        // Failure feedback is visible even though the menu already closed.
        expect(find.text('Error'), findsOneWidget);
        expect(find.text('Failed to update user profile'), findsOneWidget);
        expect(readAuthState(tester).user?.status.online, isTrue);

        // Let the toast dismiss so no timers are left pending.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'shows an error toast when the toggle fails after the menu is disposed',
      (tester) async {
        final gate = Completer<void>();
        final notifier = FakeAuthNotifier(
          initial: AuthState(
            status: AuthStatus.authenticated,
            user: _buildUser(online: true),
          ),
          toggleSucceeds: false,
          gate: gate,
        );
        await pumpOpenMenu(tester, notifier);

        await tester.tap(find.text('Set yourself as away'));
        // Let the pop animation finish so the dialog route is fully disposed
        // while the request is still pending.
        await tester.pumpAndSettle();

        expect(find.text('Set yourself as away'), findsNothing);
        expect(notifier.toggleCalls, 1);

        gate.complete();
        // One pump resumes the awaiting handler (inserting the overlay
        // entry); the next pump builds it.
        await tester.pump();
        await tester.pump();

        // Delayed failure feedback must survive the disposed dialog without
        // throwing from its WidgetRef.
        expect(tester.takeException(), isNull);
        expect(find.text('Error'), findsOneWidget);
        expect(find.text('Failed to update user profile'), findsOneWidget);
        expect(readAuthState(tester).user?.status.online, isTrue);

        // Let the toast dismiss so no timers are left pending.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'does not show an error toast when a duplicate toggle is skipped',
      (tester) async {
        final notifier = FakeAuthNotifier(
          initial: AuthState(
            status: AuthStatus.authenticated,
            user: _buildUser(online: true),
          ),
          alwaysSkips: true,
        );
        await pumpOpenMenu(tester, notifier);

        await tester.tap(find.text('Set yourself as away'));
        await tester.pumpAndSettle();

        expect(notifier.toggleCalls, 1);
        // A skipped duplicate is not a failure: no error toast may appear.
        expect(tester.takeException(), isNull);
        expect(find.text('Error'), findsNothing);
        expect(readAuthState(tester).user?.status.online, isTrue);

        // Let any toast timers settle so none are left pending.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );
  });

  group('UserMenuDialog layout', () {
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpOpenMenu(
        tester,
        FakeAuthNotifier(
          initial: AuthState(
            status: AuthStatus.authenticated,
            user: _buildUser(),
          ),
        ),
      );
    }

    testWidgets('keeps a bounded card width beside the rail', (tester) async {
      await pumpAt(tester, const Size(1280, 720));

      final card = tester.getRect(find.byKey(const ValueKey('user_menu_card')));
      expect(card.width, 288);
      expect(card.left, AppSidebarRail.width + 8);
      expect(card.right, lessThan(1280));
      expect(card.bottom, lessThanOrEqualTo(720 - 24));
    });

    testWidgets('shrinks the card instead of overhanging a narrow window', (
      tester,
    ) async {
      await pumpAt(tester, const Size(320, 720));

      final card = tester.getRect(find.byKey(const ValueKey('user_menu_card')));
      expect(card.width, 320 - AppSidebarRail.width - 8 - 16);
      expect(card.right, lessThanOrEqualTo(320 - 16));
    });
  });
}
