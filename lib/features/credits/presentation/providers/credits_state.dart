import 'package:zedu/features/features.dart';

enum CreditsStatus { initial, loading, ready, purchasing, verifying, error }

class CreditsState {
  const CreditsState({
    this.status = CreditsStatus.initial,
    this.orgId,
    this.packages = const [],
    this.usage = CreditUsage.empty,
    this.usageReport = CreditUsageReport.empty,
    this.transactions = const [],
    this.error,
    this.successMessage,
    this.purchasingPackageId,
    this.lastVerifiedSessionId,
  });

  final CreditsStatus status;

  /// The organisation the usage, report and transactions belong to.
  final String? orgId;
  final List<CreditPackage> packages;
  final CreditUsage usage;
  final CreditUsageReport usageReport;
  final List<CreditTransaction> transactions;
  final String? error;
  final String? successMessage;
  final String? purchasingPackageId;
  final String? lastVerifiedSessionId;

  bool get isLoading =>
      status == CreditsStatus.initial || status == CreditsStatus.loading;

  CreditsState copyWith({
    CreditsStatus? status,
    String? orgId,
    List<CreditPackage>? packages,
    CreditUsage? usage,
    CreditUsageReport? usageReport,
    List<CreditTransaction>? transactions,
    String? error,
    String? successMessage,
    String? purchasingPackageId,
    String? lastVerifiedSessionId,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearPurchasing = false,
  }) {
    return CreditsState(
      status: status ?? this.status,
      orgId: orgId ?? this.orgId,
      packages: packages ?? this.packages,
      usage: usage ?? this.usage,
      usageReport: usageReport ?? this.usageReport,
      transactions: transactions ?? this.transactions,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      purchasingPackageId: clearPurchasing
          ? null
          : (purchasingPackageId ?? this.purchasingPackageId),
      lastVerifiedSessionId:
          lastVerifiedSessionId ?? this.lastVerifiedSessionId,
    );
  }
}
