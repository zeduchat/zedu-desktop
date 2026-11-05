import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockCreditsRepository extends Mock implements CreditsRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'u-1',
      firstName: 'Ada',
      lastName: 'Okoro',
      email: 'ada@example.com',
      phone: '',
      username: 'ada',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-signin',
      currentOrganisationSlug: 'signin',
      avatarUrl: '',
      defaultAvatarUrl: '',
      creditBalance: 50,
    ),
  );
}

class _FixedCreditsNotifier extends CreditsNotifier {
  _FixedCreditsNotifier(this._state);

  final CreditsState _state;

  @override
  CreditsState build() => _state;
}

CreditUsage _usage(int balance) =>
    CreditUsage(balance: balance, totalPurchased: balance, totalConsumed: 0);

ProviderContainer _container({
  required String selectedOrg,
  CreditsState credits = const CreditsState(),
}) {
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      currentOrgIdProvider.overrideWithValue(selectedOrg),
      creditsNotifierProvider.overrideWith(
        () => _FixedCreditsNotifier(credits),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('creditsOrgIdProvider', () {
    test('is the workspace selected in the sidebar', () {
      final container = _container(selectedOrg: 'org-other');
      expect(container.read(creditsOrgIdProvider), 'org-other');
    });

    test('falls back to the sign-in organisation', () {
      final container = _container(selectedOrg: '');
      expect(container.read(creditsOrgIdProvider), 'org-signin');
    });
  });

  group('orgCreditBalanceProvider', () {
    test('uses the loaded balance of the selected workspace', () {
      final container = _container(
        selectedOrg: 'org-other',
        credits: CreditsState(
          status: CreditsStatus.ready,
          orgId: 'org-other',
          usage: _usage(7),
        ),
      );
      expect(container.read(orgCreditBalanceProvider), 7);
    });

    test('ignores credits loaded for another organisation', () {
      final container = _container(
        selectedOrg: 'org-other',
        credits: CreditsState(
          status: CreditsStatus.ready,
          orgId: 'org-signin',
          usage: _usage(50),
        ),
      );
      expect(container.read(orgCreditBalanceProvider), 0);
    });

    test('uses the sign-in balance only for the sign-in organisation', () {
      expect(
        _container(selectedOrg: 'org-signin').read(orgCreditBalanceProvider),
        50,
      );
      expect(
        _container(selectedOrg: 'org-other').read(orgCreditBalanceProvider),
        0,
      );
    });
  });

  group('CreditsNotifier.load', () {
    late _MockCreditsRepository repository;

    setUp(() {
      repository = _MockCreditsRepository();
      when(
        () => repository.getPackages(),
      ).thenAnswer((_) async => const Success(<CreditPackage>[]));
      when(
        () => repository.getUsageReport(any()),
      ).thenAnswer((_) async => const Success(CreditUsageReport.empty));
      when(
        () => repository.getTransactions(any()),
      ).thenAnswer((_) async => const Success(<CreditTransaction>[]));
    });

    ProviderContainer loadContainer() {
      final container = ProviderContainer(
        overrides: [creditsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('keeps the usage of the organisation it loaded', () async {
      when(
        () => repository.getUsage('org-a'),
      ).thenAnswer((_) async => Success(_usage(10)));
      final container = loadContainer();

      await container
          .read(creditsNotifierProvider.notifier)
          .load(orgId: 'org-a');

      final state = container.read(creditsNotifierProvider);
      expect(state.orgId, 'org-a');
      expect(state.usage.balance, 10);
    });

    test('drops a slower load for the previous organisation', () async {
      final slowUsage = Completer<Result<CreditUsage>>();
      when(
        () => repository.getUsage('org-a'),
      ).thenAnswer((_) => slowUsage.future);
      when(
        () => repository.getUsage('org-b'),
      ).thenAnswer((_) async => Success(_usage(20)));
      final container = loadContainer();
      final notifier = container.read(creditsNotifierProvider.notifier);

      final first = notifier.load(orgId: 'org-a');
      await notifier.load(orgId: 'org-b');
      slowUsage.complete(Success(_usage(99)));
      await first;

      final state = container.read(creditsNotifierProvider);
      expect(state.orgId, 'org-b');
      expect(state.usage.balance, 20);
    });
  });
}
