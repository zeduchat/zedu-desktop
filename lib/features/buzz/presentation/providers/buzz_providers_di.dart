import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The app's config, so it can be overridden in tests.
final buzzConfigProvider = Provider<AppConfig>((ref) => locator<AppConfig>());

/// The organisation the server creates meetings in: the signed-in user's
/// current one.
final buzzOrgSlugProvider = Provider<String>(
  (ref) =>
      ref.watch(authNotifierProvider).user?.currentOrganisationSlug.trim() ??
      '',
);

/// Whether someone is signed in, so Buzz can tell a missing session apart
/// from a workspace whose slug has not been loaded.
final buzzSignedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return auth.status == AuthStatus.authenticated && auth.user != null;
});

final buzzMeetingsRemoteDataSourceProvider =
    Provider<BuzzMeetingsRemoteDataSource>(
      (ref) => BuzzMeetingsRemoteDataSourceImpl(
        apiBaseService: locator<ApiBaseService>(),
      ),
    );

final buzzMeetingsRepositoryProvider = Provider<BuzzMeetingsRepository>(
  (ref) => BuzzMeetingsRepositoryImpl(
    remoteDataSource: ref.watch(buzzMeetingsRemoteDataSourceProvider),
  ),
);

final buzzMeetingsProvider =
    NotifierProvider<BuzzMeetingsNotifier, BuzzMeetingAction>(
      BuzzMeetingsNotifier.new,
    );
