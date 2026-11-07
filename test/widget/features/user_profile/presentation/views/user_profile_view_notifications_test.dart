import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeProfileNotifier extends UserProfileNotifier {
  _FakeProfileNotifier(this.initial);

  final UserProfileState initial;
  int loads = 0;
  final saved = <NotificationPreferences>[];

  @override
  UserProfileState build() => initial;

  @override
  Future<void> load() async => loads++;

  @override
  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async => saved.add(preferences);
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

Future<_FakeProfileNotifier> _pump(
  WidgetTester tester,
  UserProfileState state, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final notifier = _FakeProfileNotifier(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileNotifierProvider.overrideWith(() => notifier),
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        orgCreditBalanceProvider.overrideWithValue(0),
      ],
      child: buildTestMaterialApp(const UserProfileView()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return notifier;
}

void main() {
  setUp(() {
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'https://example.com/', usesMockData: false),
    );
  });

  tearDown(() async {
    await locator.unregister<AppConfig>();
  });

  testWidgets(
    'a failed notification load offers a retry, not editable defaults',
    (tester) async {
      final notifier = await _pump(
        tester,
        const UserProfileState(section: UserProfileSection.notifications),
      );

      expect(
        find.text("We couldn't load your notification settings."),
        findsOneWidget,
      );
      expect(find.byType(NotificationsSection), findsNothing);
      expect(find.byType(Switch), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(notifier.loads, 1);
      expect(notifier.saved, isEmpty);
    },
  );

  testWidgets('a failed member load offers a retry, not an empty team', (
    tester,
  ) async {
    final notifier = await _pump(
      tester,
      const UserProfileState(
        section: UserProfileSection.userManagement,
        teamMembersLoadFailed: true,
      ),
    );

    expect(find.text("We couldn't load your team members."), findsOneWidget);
    expect(find.byType(UserManagementSection), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(notifier.loads, 1);
  });

  testWidgets('an empty team that loaded shows the section', (tester) async {
    await _pump(
      tester,
      const UserProfileState(section: UserProfileSection.userManagement),
    );

    expect(find.byType(UserManagementSection), findsOneWidget);
    expect(find.text("We couldn't load your team members."), findsNothing);
  });

  testWidgets('shows a spinner while the notifications are loading', (
    tester,
  ) async {
    await _pump(
      tester,
      const UserProfileState(
        section: UserProfileSection.notifications,
        isLoading: true,
      ),
      // A spinning indicator never settles.
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(NotificationsSection), findsNothing);
  });

  testWidgets('loaded notification settings show the section', (tester) async {
    await _pump(
      tester,
      UserProfileState(
        section: UserProfileSection.notifications,
        notifications: NotificationPreferences.empty(),
      ),
    );

    expect(find.byType(NotificationsSection), findsOneWidget);
    expect(
      find.text("We couldn't load your notification settings."),
      findsNothing,
    );
  });
}
