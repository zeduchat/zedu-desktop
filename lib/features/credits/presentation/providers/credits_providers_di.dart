import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final creditsRemoteDataSourceProvider = Provider<CreditsRemoteDataSource>(
  (ref) => CreditsRemoteDataSourceImpl(
    config: locator<AppConfig>(),
    apiBaseService: locator<ApiBaseService>(),
  ),
);

final creditsRepositoryProvider = Provider<CreditsRepository>(
  (ref) =>
      CreditsRepositoryImpl(remote: ref.watch(creditsRemoteDataSourceProvider)),
);

final creditsNotifierProvider = NotifierProvider<CreditsNotifier, CreditsState>(
  CreditsNotifier.new,
);

/// The organisation credits are shown for: the workspace selected in the
/// sidebar, or the sign-in organisation before a workspace is selected.
final creditsOrgIdProvider = Provider<String>((ref) {
  final selected = ref.watch(currentOrgIdProvider);
  if (selected.isNotEmpty) return selected;
  return ref.watch(authNotifierProvider.select((s) => s.user?.currentOrg)) ??
      '';
});

final orgCreditBalanceProvider = Provider<int>((ref) {
  final orgId = ref.watch(creditsOrgIdProvider);
  final creditsState = ref.watch(creditsNotifierProvider);
  // An error with the packages already loaded is a failed purchase or
  // payment check, not a failed load, so the balance loaded earlier is still
  // the right one to show.
  final usageIsLoaded =
      creditsState.status == CreditsStatus.ready ||
      creditsState.status == CreditsStatus.purchasing ||
      creditsState.status == CreditsStatus.verifying ||
      (creditsState.status == CreditsStatus.error &&
          creditsState.packages.isNotEmpty);
  if (creditsState.orgId == orgId && usageIsLoaded) {
    return creditsState.usage.balance;
  }
  // The sign-in response only carries the sign-in organisation's balance.
  final user = ref.watch(authNotifierProvider).user;
  if (user == null || user.currentOrg != orgId) return 0;
  return user.creditBalance;
});
