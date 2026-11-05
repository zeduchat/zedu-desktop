import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class CreditsRepositoryImpl implements CreditsRepository {
  const CreditsRepositoryImpl({required CreditsRemoteDataSource remote})
    : _remote = remote;

  final CreditsRemoteDataSource _remote;

  static const _tag = 'CreditsRepository';

  @override
  Future<Result<List<CreditPackage>>> getPackages() =>
      _guard(_remote.getPackages);

  @override
  Future<Result<CreditUsage>> getUsage(String orgId) =>
      _guard(() => _remote.getUsage(orgId));

  @override
  Future<Result<CreditUsageReport>> getUsageReport(String orgId) =>
      _guard(() => _remote.getUsageReport(orgId));

  @override
  Future<Result<List<CreditTransaction>>> getTransactions(String orgId) =>
      _guard(() => _remote.getTransactions(orgId));

  @override
  Future<Result<CreditCheckoutSession>> purchaseCredits({
    String? packageId,
    String? planId,
    required String email,
  }) {
    return _guard(
      () => _remote.purchaseCredits(
        packageId: packageId,
        planId: planId,
        email: email,
      ),
    );
  }

  @override
  Future<Result<void>> verifyPayment({required String sessionId}) {
    return _guard(() => _remote.verifyPayment(sessionId: sessionId));
  }

  Future<Result<T>> _guard<T>(Future<T> Function() operation) async {
    try {
      return Success(await operation());
    } on ApiFailure catch (failure) {
      AppLogger.w('Credits request failed - ${failure.message}', tag: _tag);
      return Failure(failure);
    } catch (error) {
      AppLogger.e('Unexpected credits error', tag: _tag, error: error);
      return Failure(ApiFailure.unknown(error));
    }
  }
}
