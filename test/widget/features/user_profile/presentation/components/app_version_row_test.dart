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
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  void mockVersion({String version = '1.2.3', String buildNumber = '45'}) {
    PackageInfo.setMockInitialValues(
      appName: 'zedu',
      packageName: 'com.zedu.desktopApp',
      version: version,
      buildNumber: buildNumber,
      buildSignature: '',
    );
  }

  Future<void> pumpRow(WidgetTester tester, {List<dynamic>? overrides}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...?overrides?.cast()],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: AppVersionRow()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the version and build number', (tester) async {
    mockVersion();
    await pumpRow(tester);

    expect(find.text('Version 1.2.3 (45)'), findsOneWidget);
    expect(find.byTooltip('Copy version'), findsOneWidget);
  });

  testWidgets('leaves out an empty build number', (tester) async {
    mockVersion(buildNumber: '');
    await pumpRow(tester);

    expect(find.text('Version 1.2.3'), findsOneWidget);
  });

  testWidgets('copies the version and confirms it', (tester) async {
    mockVersion();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpRow(tester);
    await tester.tap(find.byTooltip('Copy version'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(copied, 'Version 1.2.3 (45)');
    expect(find.text('Version copied'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('shows nothing when the version cannot be read', (tester) async {
    await pumpRow(
      tester,
      overrides: [
        appVersionProvider.overrideWith((ref) async => throw Exception('no')),
      ],
    );

    expect(find.textContaining('Version'), findsNothing);
    expect(find.byTooltip('Copy version'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('Settings navigation', () {
    Future<void> pumpShell(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
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
            theme: AppTheme.light,
            home: ProfileSettingsShell(
              selectedSection: UserProfileSection.account,
              onSectionSelected: (_) {},
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows the version', (tester) async {
      mockVersion();
      await pumpShell(tester, const Size(1280, 800));

      expect(find.text('Version 1.2.3 (45)'), findsOneWidget);
    });

    testWidgets('keeps the version on screen in a short window', (
      tester,
    ) async {
      mockVersion();
      await pumpShell(tester, const Size(1280, 590));

      final version = find.text('Version 1.2.3 (45)');
      expect(version, findsOneWidget);
      expect(tester.getBottomLeft(version).dy, lessThan(590));
      expect(tester.takeException(), isNull);
      // The list scrolls behind the row, so every section can still be reached.
      expect(
        find.ancestor(
          of: find.text('Billing'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });
  });
}
