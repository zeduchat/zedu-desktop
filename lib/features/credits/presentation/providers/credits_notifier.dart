import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class CreditsNotifier extends Notifier<CreditsState> {
  late final CreditsRepository _repository;
  bool _purchaseInFlight = false;

  static const _tag = 'CreditsNotifier';

  /// Bumped by every [load]; an older request that finishes later sees a
  /// different value and stops instead of overwriting newer state.
  int _loadGeneration = 0;

  @override
  CreditsState build() {
    _repository = ref.read(creditsRepositoryProvider);
    return const CreditsState();
  }

  Future<void> load({String? orgId}) async {
    if (orgId == null || orgId.isEmpty) return;

    final generation = ++_loadGeneration;
    // Another organisation's usage and history must not show for this one.
    if (state.orgId != orgId) {
      state = CreditsState(
        packages: state.packages,
        lastVerifiedSessionId: state.lastVerifiedSessionId,
      );
    }
    state = state.copyWith(
      status: CreditsStatus.loading,
      orgId: orgId,
      clearError: true,
      clearSuccess: true,
    );

    final packagesResult = await _repository.getPackages();
    final usageResult = await _repository.getUsage(orgId);
    final reportResult = await _repository.getUsageReport(orgId);
    final transactionsResult = await _repository.getTransactions(orgId);
    // A newer load owns the state now: drop this one's results, success or
    // failure, so an earlier workspace cannot replace the current balance.
    if (generation != _loadGeneration) return;
    // A load for another organisation started meanwhile; its result wins.
    if (state.orgId != orgId) return;

    String? error;
    var packages = state.packages;
    var usage = state.usage;
    var report = state.usageReport;
    var transactions = state.transactions;

    switch (packagesResult) {
      case Success<List<CreditPackage>>():
        packages = packagesResult.value;
      case Failure<List<CreditPackage>>():
        error = packagesResult.error.friendlyMessage;
    }
    switch (usageResult) {
      case Success<CreditUsage>():
        usage = usageResult.value;
      case Failure<CreditUsage>():
        error ??= usageResult.error.friendlyMessage;
    }
    switch (reportResult) {
      case Success<CreditUsageReport>():
        report = reportResult.value;
      case Failure<CreditUsageReport>():
        error ??= reportResult.error.friendlyMessage;
    }
    switch (transactionsResult) {
      case Success<List<CreditTransaction>>():
        transactions = transactionsResult.value;
      case Failure<List<CreditTransaction>>():
        error ??= transactionsResult.error.friendlyMessage;
    }

    state = state.copyWith(
      status: error != null && packages.isEmpty
          ? CreditsStatus.error
          : CreditsStatus.ready,
      packages: packages,
      usage: usage,
      usageReport: report,
      transactions: transactions,
      error: error,
    );
  }

  Future<CreditCheckoutSession?> purchasePackage({
    required CreditPackage package,
    required String email,
  }) async {
    if (package.isFree || _purchaseInFlight) {
      final navigator = AppRouter.navigatorKey.currentState;
      if (navigator != null) {
        AppToastService.showAtRoot(
          navigator,
          type: AppToastType.error,
          message: package.isFree
              ? 'This package is free, so there is nothing to purchase'
              : 'A purchase is already in progress',
        );
      }
      return null;
    }
    _purchaseInFlight = true;

    try {
      state = state.copyWith(
        status: CreditsStatus.purchasing,
        purchasingPackageId: package.id,
        clearError: true,
        clearSuccess: true,
      );

      final result = await _repository.purchaseCredits(
        packageId: package.id,
        planId: package.id,
        email: email,
      );

      switch (result) {
        case Success<CreditCheckoutSession>():
          state = state.copyWith(
            status: CreditsStatus.ready,
            clearPurchasing: true,
          );
          return result.value;
        case Failure<CreditCheckoutSession>():
          AppLogger.w('Purchase failed — ${result.error.message}', tag: _tag);
          state = state.copyWith(
            status: CreditsStatus.error,
            error: result.error.friendlyMessage,
            clearPurchasing: true,
          );
          return null;
      }
    } finally {
      _purchaseInFlight = false;
    }
  }

  Future<bool> verifyPayment({
    required String sessionId,
    required String orgId,
  }) async {
    if (sessionId.isEmpty) return false;
    if (state.lastVerifiedSessionId == sessionId) return true;

    state = state.copyWith(
      status: CreditsStatus.verifying,
      clearError: true,
      clearSuccess: true,
    );

    final result = await _repository.verifyPayment(sessionId: sessionId);
    switch (result) {
      case Success<void>():
        await load(orgId: orgId);
        await ref.read(authNotifierProvider.notifier).refreshCurrentUser();
        state = state.copyWith(
          status: CreditsStatus.ready,
          lastVerifiedSessionId: sessionId,
          successMessage: 'Payment verified. AI credits are now available.',
        );
        return true;
      case Failure<void>():
        state = state.copyWith(
          status: CreditsStatus.error,
          error: result.error.friendlyMessage,
        );
        return false;
    }
  }
}
