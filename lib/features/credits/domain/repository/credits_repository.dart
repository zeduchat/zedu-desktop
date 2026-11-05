import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract interface class CreditsRepository {
  Future<Result<List<CreditPackage>>> getPackages();
  Future<Result<CreditUsage>> getUsage(String orgId);
  Future<Result<CreditUsageReport>> getUsageReport(String orgId);
  Future<Result<List<CreditTransaction>>> getTransactions(String orgId);
  Future<Result<CreditCheckoutSession>> purchaseCredits({
    String? packageId,
    String? planId,
    required String email,
  });
  Future<Result<void>> verifyPayment({required String sessionId});
}
