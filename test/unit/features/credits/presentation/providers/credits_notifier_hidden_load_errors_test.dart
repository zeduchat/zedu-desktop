import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _MockCreditsRepository extends Mock implements CreditsRepository {}

const _orgId = 'org-1';
const _package = CreditPackage(
  id: 'pro',
  name: 'Pro',
  description: '',
  price: 20,
  credits: 5000,
  benefits: [],
);
const _usage = CreditUsage(balance: 40, totalPurchased: 40, totalConsumed: 0);
const _report = CreditUsageReport(
  balance: 40,
  purchased: 40,
  consumed: 0,
  periodLabel: 'This month',
);
const _down = ApiFailure(message: 'The resource was not found');

void main() {
  late _MockCreditsRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _MockCreditsRepository();
    when(
      () => repository.getPackages(),
    ).thenAnswer((_) async => const Success([_package]));
    when(
      () => repository.getUsage(_orgId),
    ).thenAnswer((_) async => const Success(_usage));
    container = ProviderContainer(
      overrides: [creditsRepositoryProvider.overrideWithValue(repository)],
    );
  });
  tearDown(() => container.dispose());

  void failHiddenLoads() {
    when(
      () => repository.getUsageReport(_orgId),
    ).thenAnswer((_) async => const Failure<CreditUsageReport>(_down));
    when(
      () => repository.getTransactions(_orgId),
    ).thenAnswer((_) async => const Failure<List<CreditTransaction>>(_down));
  }

  test('report and transaction failures raise no error', () async {
    failHiddenLoads();

    await container.read(creditsNotifierProvider.notifier).load(orgId: _orgId);

    final state = container.read(creditsNotifierProvider);
    expect(state.error, isNull);
    expect(state.status, CreditsStatus.ready);
    expect(state.packages, [_package]);
    expect(state.usage, same(_usage));
  });

  test('a failed reload keeps the previous report', () async {
    when(
      () => repository.getUsageReport(_orgId),
    ).thenAnswer((_) async => const Success(_report));
    when(
      () => repository.getTransactions(_orgId),
    ).thenAnswer((_) async => const Success(<CreditTransaction>[]));
    final notifier = container.read(creditsNotifierProvider.notifier);
    await notifier.load(orgId: _orgId);

    failHiddenLoads();
    await notifier.load(orgId: _orgId);

    final state = container.read(creditsNotifierProvider);
    expect(state.usageReport, same(_report));
    expect(state.error, isNull);
  });

  test('a usage failure still raises the error', () async {
    failHiddenLoads();
    when(
      () => repository.getUsage(_orgId),
    ).thenAnswer((_) async => const Failure<CreditUsage>(_down));

    await container.read(creditsNotifierProvider.notifier).load(orgId: _orgId);

    expect(
      container.read(creditsNotifierProvider).error,
      _down.friendlyMessage,
    );
  });
}
