import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final workspaceRemoteDataSourceProvider = Provider<WorkspaceRemoteDataSource>(
  (ref) =>
      WorkspaceRemoteDataSourceImpl(apiBaseService: locator<ApiBaseService>()),
);
