import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class _FakeCreditsNotifier extends CreditsNotifier {
  @override
  CreditsState build() => const CreditsState();

  @override
  Future<void> load({String? orgId}) async {}
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

void main() {
  setUp(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
    );
    PackageInfo.setMockInitialValues(
      appName: 'zedu',
      packageName: 'com.zedu.desktopApp',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    ValueChanged<UserProfileSection>? onSectionSelected,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          creditsNotifierProvider.overrideWith(_FakeCreditsNotifier.new),
          userProfileNotifierProvider.overrideWith(
            _FakeUserProfileNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: ProfileSettingsShell(
            selectedSection: UserProfileSection.account,
            onSectionSelected: onSectionSelected ?? (_) {},
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  const personalTiles = ['Account', 'Notifications', 'Desktop', 'Security'];
  const organizationTiles = [
    'General',
    'User management',
    'Roles & permissions',
    'Billing',
  ];

  void expectTiles(List<String> labels, Matcher matcher) {
    for (final label in labels) {
      expect(find.text(label), matcher, reason: label);
    }
  }

  for (final (name, theme, palette) in [
    ('light', AppTheme.light, AppPalette.light),
    ('dark', AppTheme.dark, AppPalette.dark),
  ]) {
    testWidgets('the content pane uses the $name background', (tester) async {
      await pumpShell(tester, theme: theme);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, palette.background);
    });
  }

  group('Settings navigation groups', () {
    testWidgets('both groups start expanded', (tester) async {
      await pumpShell(tester);

      expectTiles(personalTiles, findsOneWidget);
      expectTiles(organizationTiles, findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_right), findsNothing);
    });

    testWidgets('Personal collapses and expands on its own', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text('Personal'));
      await tester.pump();

      expectTiles(personalTiles, findsNothing);
      expectTiles(organizationTiles, findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_right), findsOneWidget);

      await tester.tap(find.text('Personal'));
      await tester.pump();

      expectTiles(personalTiles, findsOneWidget);
      expect(find.byIcon(Icons.arrow_right), findsNothing);
    });

    testWidgets('Organization collapses and expands on its own', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(find.text('Organization'));
      await tester.pump();

      expectTiles(organizationTiles, findsNothing);
      expectTiles(personalTiles, findsOneWidget);
      expect(find.text('Organization'), findsOneWidget);

      await tester.tap(find.text('Organization'));
      await tester.pump();

      expectTiles(organizationTiles, findsOneWidget);
    });

    testWidgets('both groups can be collapsed at once', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text('Personal'));
      await tester.pump();
      await tester.tap(find.text('Organization'));
      await tester.pump();

      expectTiles(personalTiles, findsNothing);
      expectTiles(organizationTiles, findsNothing);
      expect(find.byIcon(Icons.arrow_right), findsNWidgets(2));
    });

    testWidgets('group headers are buttons that report their state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpShell(tester);

      expect(
        tester.getSemantics(find.text('Personal')),
        matchesSemantics(
          label: 'Personal',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.text('Personal'));
      await tester.pump();

      expect(
        tester.getSemantics(find.text('Personal')),
        matchesSemantics(
          label: 'Personal',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('tiles still select their section when expanded', (
      tester,
    ) async {
      UserProfileSection? selected;
      await pumpShell(tester, onSectionSelected: (s) => selected = s);

      await tester.tap(find.text('Organization'));
      await tester.pump();
      await tester.tap(find.text('Organization'));
      await tester.pump();
      await tester.tap(find.text('Billing'));
      await tester.pump();

      expect(selected, UserProfileSection.billing);
    });
  });
}
