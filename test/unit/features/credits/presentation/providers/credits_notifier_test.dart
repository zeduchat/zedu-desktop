import 'dart:async';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class MockCreditsRepository extends Mock implements CreditsRepository {}

const _pro = CreditPackage(
  id: 'pro',
  name: 'Pro',
  description: '',
  price: 20,
  credits: 5000,
  benefits: [],
);
const _business = CreditPackage(
  id: 'business',
  name: 'Business',
  description: '',
  price: 50,
  credits: 15000,
  benefits: [],
);
const _session = CreditCheckoutSession(
  checkoutSessionId: 'checkout',
  checkoutSessionUrl: 'https://example.invalid/checkout',
);
const _email = 'tester@example.com';

void main() {
  late MockCreditsRepository repository;
  late ProviderContainer container;
  late CreditsNotifier notifier;
  late Completer<Result<CreditCheckoutSession>> pending;

  setUp(() {
    repository = MockCreditsRepository();
    pending = Completer<Result<CreditCheckoutSession>>();
    when(
      () => repository.purchaseCredits(
        packageId: any(named: 'packageId'),
        planId: any(named: 'planId'),
        email: _email,
      ),
    ).thenAnswer((_) => pending.future);
    container = ProviderContainer(
      overrides: [creditsRepositoryProvider.overrideWithValue(repository)],
    );
    notifier = container.read(creditsNotifierProvider.notifier);
  });
  tearDown(() => container.dispose());

  for (final repeated in [_pro, _business]) {
    test('ignore ${repeated.id} while the pro checkout is pending', () async {
      final first = notifier.purchasePackage(package: _pro, email: _email);
      final duplicate = notifier.purchasePackage(
        package: repeated,
        email: _email,
      );
      expect(
        container.read(creditsNotifierProvider).purchasingPackageId,
        _pro.id,
      );
      verify(
        () => repository.purchaseCredits(
          packageId: _pro.id,
          planId: _pro.id,
          email: _email,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
      pending.complete(const Success(_session));
      expect(await first, same(_session));
      expect(await duplicate, isNull);
    });
  }

  for (final fails in [false, true]) {
    test(
      'allow another checkout after ${fails ? 'failure' : 'success'}',
      () async {
        final first = notifier.purchasePackage(package: _pro, email: _email);
        pending.complete(
          fails
              ? const Failure(ApiFailure(message: 'Checkout unavailable'))
              : const Success(_session),
        );
        expect(await first, fails ? isNull : same(_session));
        final state = container.read(creditsNotifierProvider);
        expect(state.purchasingPackageId, isNull);
        expect(state.status, fails ? CreditsStatus.error : CreditsStatus.ready);
        if (fails) expect(state.error, contains('Checkout unavailable'));

        pending = Completer<Result<CreditCheckoutSession>>();
        final retry = notifier.purchasePackage(
          package: _business,
          email: _email,
        );
        expect(container.read(creditsNotifierProvider).error, isNull);
        expect(
          container.read(creditsNotifierProvider).purchasingPackageId,
          _business.id,
        );
        pending.complete(const Success(_session));
        expect(await retry, same(_session));
        verify(
          () => repository.purchaseCredits(
            packageId: _business.id,
            planId: _business.id,
            email: _email,
          ),
        ).called(1);
      },
    );
  }

  test('free plan does not create a checkout', () async {
    const free = CreditPackage(
      id: 'free',
      name: 'Free',
      description: '',
      price: 0,
      credits: 0,
      benefits: [],
    );
    expect(
      await notifier.purchasePackage(package: free, email: _email),
      isNull,
    );
    verifyZeroInteractions(repository);
  });
}
