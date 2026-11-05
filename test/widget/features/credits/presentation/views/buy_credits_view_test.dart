import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockCreditsRepository extends Mock implements CreditsRepository {}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'sample-user',
      firstName: 'Sample',
      lastName: 'User',
      email: 'sample@example.com',
      phone: '',
      username: 'SampleUser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime.utc(2026, 1, 1),
      currentOrg: 'test-org',
      currentOrganisationSlug: 'test-org',
      avatarUrl: '',
      defaultAvatarUrl: '',
      creditBalance: 100,
    ),
  );
}

class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() =>
      const UserProfileState(section: UserProfileSection.billing);
}

class _FakeAuthNoOrgNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'sample-user',
      firstName: 'Sample',
      lastName: 'User',
      email: 'sample@example.com',
      phone: '',
      username: 'SampleUser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime.utc(2026, 1, 1),
      currentOrg: '',
      currentOrganisationSlug: '',
      avatarUrl: '',
      defaultAvatarUrl: '',
      creditBalance: 100,
    ),
  );
}

class _FakeCurrentOrgNotifier extends Notifier<String> {
  @override
  String build() => 'org-initial';

  void setOrg(String orgId) => state = orgId;
}

final _testOrgIdProvider = NotifierProvider<_FakeCurrentOrgNotifier, String>(
  _FakeCurrentOrgNotifier.new,
);

class FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();
}

const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  group('Enterprise plan button', () {
    final launchedUrls = <String>[];
    var launchSucceeds = true;

    setUp(() {
      launchedUrls.clear();
      launchSucceeds = true;
      locator.registerSingleton<AppConfig>(
        const AppConfig(
          apiBaseUrl: 'https://example.com/',
          usesMockData: false,
        ),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
            launchedUrls.add((call.arguments as Map)['url'] as String);
            return launchSucceeds;
          });
    });

    tearDown(() async {
      await locator.unregister<AppConfig>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_urlLauncherChannel, null);
    });

    Future<void> tapContactSales(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockCreditsRepository();
      when(repository.getPackages).thenAnswer(
        (_) async => const Success<List<CreditPackage>>([
          CreditPackage(
            id: 'enterprise',
            name: 'Enterprise',
            description: 'For large teams',
            price: 1000,
            credits: 1000,
            benefits: [],
          ),
        ]),
      );
      when(() => repository.getUsage('test-org')).thenAnswer(
        (_) async => const Success(
          CreditUsage(balance: 0, totalPurchased: 0, totalConsumed: 0),
        ),
      );
      when(
        () => repository.getUsageReport('test-org'),
      ).thenAnswer((_) async => const Success(CreditUsageReport.empty));
      when(
        () => repository.getTransactions('test-org'),
      ).thenAnswer((_) async => const Success<List<CreditTransaction>>([]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(FakeAuthNotifier.new),
            userProfileNotifierProvider.overrideWith(
              FakeUserProfileNotifier.new,
            ),
            creditsRepositoryProvider.overrideWithValue(repository),
            workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
          ],
          // The test font is wide enough to overflow the plan card's fixed height.
          child: buildTestMaterialApp(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(0.5)),
                child: const BuyCreditsView(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Contact Sales'));
      await tester.pump();
    }

    testWidgets('opens the Contact Sales page with no success toast', (
      tester,
    ) async {
      await tapContactSales(tester);

      expect(launchedUrls, [kDefaultContactSalesUrl]);
      expect(find.textContaining('Contacting Sales'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('shows an error toast if the page cannot be opened', (
      tester,
    ) async {
      launchSucceeds = false;

      await tapContactSales(tester);
      await tester.pump();

      expect(
        find.text('Could not open the Contact Sales page.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
    });
  });

  for (final balance in [0, 25]) {
    testWidgets('Billing and user menu show the loaded balance of $balance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockCreditsRepository();
      final usage = Completer<Result<CreditUsage>>();
      when(
        repository.getPackages,
      ).thenAnswer((_) async => const Success<List<CreditPackage>>([]));
      when(
        () => repository.getUsage('test-org'),
      ).thenAnswer((_) => usage.future);
      when(
        () => repository.getUsageReport('test-org'),
      ).thenAnswer((_) async => const Success(CreditUsageReport.empty));
      when(
        () => repository.getTransactions('test-org'),
      ).thenAnswer((_) async => const Success<List<CreditTransaction>>([]));

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(FakeAuthNotifier.new),
          userProfileNotifierProvider.overrideWith(FakeUserProfileNotifier.new),
          creditsRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(const BuyCreditsView()),
        ),
      );
      await tester.pump();
      expect(
        container.read(creditsNotifierProvider).status,
        CreditsStatus.loading,
      );
      expect(find.text('100 AI credits'), findsOneWidget);

      usage.complete(
        Success(
          CreditUsage(
            balance: balance,
            totalPurchased: 100,
            totalConsumed: 100 - balance,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(creditsNotifierProvider).status,
        CreditsStatus.ready,
      );
      expect(container.read(authNotifierProvider).user!.creditBalance, 100);
      expect(find.text('$balance AI credits'), findsOneWidget);
      expect(find.text('100 AI credits'), findsNothing);

      await tester.tap(find.byType(TopUserMenu));
      await tester.pumpAndSettle();
      expect(find.text('AI Credits: $balance'), findsOneWidget);
      expect(find.text('$balance AI credits'), findsOneWidget);
      expect(tester.takeException(), isNull);
      verify(() => repository.getUsage('test-org')).called(1);
    });
  }

  testWidgets(
    'loads credits using currentOrgIdProvider when auth user currentOrg is empty',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockCreditsRepository();
      when(
        repository.getPackages,
      ).thenAnswer((_) async => const Success<List<CreditPackage>>([]));
      when(() => repository.getUsage('workspace-org-1')).thenAnswer(
        (_) async => const Success(
          CreditUsage(balance: 50, totalPurchased: 50, totalConsumed: 0),
        ),
      );
      when(
        () => repository.getUsageReport('workspace-org-1'),
      ).thenAnswer((_) async => const Success(CreditUsageReport.empty));
      when(
        () => repository.getTransactions('workspace-org-1'),
      ).thenAnswer((_) async => const Success<List<CreditTransaction>>([]));

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNoOrgNotifier.new),
          userProfileNotifierProvider.overrideWith(FakeUserProfileNotifier.new),
          creditsRepositoryProvider.overrideWithValue(repository),
          currentOrgIdProvider.overrideWithValue('workspace-org-1'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(const BuyCreditsView()),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => repository.getUsage('workspace-org-1')).called(1);
    },
  );

  testWidgets(
    'reloads credits packages when currentOrgIdProvider updates to a new organization',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockCreditsRepository();
      when(
        repository.getPackages,
      ).thenAnswer((_) async => const Success<List<CreditPackage>>([]));
      when(() => repository.getUsage(any())).thenAnswer(
        (_) async => const Success(
          CreditUsage(balance: 10, totalPurchased: 10, totalConsumed: 0),
        ),
      );
      when(
        () => repository.getUsageReport(any()),
      ).thenAnswer((_) async => const Success(CreditUsageReport.empty));
      when(
        () => repository.getTransactions(any()),
      ).thenAnswer((_) async => const Success<List<CreditTransaction>>([]));

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNoOrgNotifier.new),
          userProfileNotifierProvider.overrideWith(FakeUserProfileNotifier.new),
          creditsRepositoryProvider.overrideWithValue(repository),
          currentOrgIdProvider.overrideWith(
            (ref) => ref.watch(_testOrgIdProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(const BuyCreditsView()),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => repository.getUsage('org-initial')).called(1);

      container.read(_testOrgIdProvider.notifier).setOrg('org-switched');
      await tester.pumpAndSettle();

      verify(() => repository.getUsage('org-switched')).called(1);
    },
  );
}
