import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final peopleRemoteDataSourceProvider = Provider<PeopleRemoteDataSource>(
  (ref) =>
      PeopleRemoteDataSourceImpl(apiBaseService: locator<ApiBaseService>()),
);

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => PeopleRepositoryImpl(
    remoteDataSource: ref.watch(peopleRemoteDataSourceProvider),
  ),
);

/// Members matching a search; '' lists everyone.
final peopleListProvider = AsyncNotifierProvider.autoDispose
    .family<PeopleListNotifier, PeopleListState, String>(
      PeopleListNotifier.new,
    );

final peopleActionsProvider = NotifierProvider<PeopleActionsNotifier, String?>(
  PeopleActionsNotifier.new,
);
