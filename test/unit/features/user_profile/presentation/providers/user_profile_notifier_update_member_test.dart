import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockRepo extends Mock implements UserProfileRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace', avatar: ''),
  );
}

/// Answers `GET /organisations/{orgId}/roles` with [roles].
ApiBaseService _rolesApi(AppConfig config, List<Map<String, dynamic>> roles) {
  final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          data: {'data': roles},
        ),
      ),
    ),
  );
  return ApiBaseService(config: config, dio: dio);
}

const _owner = TeamMember(
  id: 'user-1',
  email: 'owner@zedu.test',
  role: 'Owner',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
);

void main() {
  group('UserProfileNotifier.updateMember', () {
    late _MockRepo repo;

    setUpAll(() => registerFallbackValue(_owner));

    setUp(() {
      repo = _MockRepo();
      final config = AppConfig(
        apiBaseUrl: 'https://api.example.com',
        usesMockData: false,
      );
      final storage = _MockStorage();
      when(() => storage.readData(any())).thenAnswer((_) async => null);
      locator
        ..registerSingleton<AppConfig>(config)
        ..registerSingleton<SecureStorageService>(storage)
        ..registerSingleton<ApiBaseService>(
          _rolesApi(config, const [
            {'id': 'role-owner', 'name': 'Owner'},
            {'id': 'role-manager', 'name': 'Manager'},
          ]),
        );

      when(
        () => repo.getAccount(),
      ).thenAnswer((_) async => Success(ProfileAccount.empty()));
      when(
        () => repo.getNotificationPreferences(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => Success(NotificationPreferences.empty()));
      when(
        () => repo.getSecuritySessions(userId: any(named: 'userId')),
      ).thenAnswer((_) async => Success(<SecuritySession>[]));
      when(() => repo.getOrganization(orgId: any(named: 'orgId'))).thenAnswer(
        (_) async => const Success(
          OrganizationProfile(
            id: '',
            name: '',
            natureOfBusiness: '',
            country: '',
          ),
        ),
      );
      when(
        () => repo.getTeamMembers(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => const Success<List<TeamMember>>([_owner]));
      when(
        () => repo.getRolesAndPermissions(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => Success(<RolePermission>[]));
      when(
        () => repo.getBillingInfo(),
      ).thenAnswer((_) async => Success(BillingInfo.empty()));
    });

    tearDown(() async => locator.reset());

    Future<ProviderContainer> loaded() async {
      final container = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repo),
          workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      container.listen(userProfileNotifierProvider, (_, _) {});
      while (container.read(userProfileNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      return container;
    }

    test('sends the role id of the chosen role and keeps its name', () async {
      when(
        () => repo.updateMember(
          any(),
          roleId: any(named: 'roleId'),
          orgId: any(named: 'orgId'),
        ),
      ).thenAnswer(
        (invocation) async =>
            Success(invocation.positionalArguments.first as TeamMember),
      );
      final container = await loaded();

      await container
          .read(userProfileNotifierProvider.notifier)
          .updateMember(_owner.copyWith(role: 'Manager'));

      verify(
        () => repo.updateMember(
          any(that: isA<TeamMember>().having((m) => m.id, 'id', 'user-1')),
          roleId: 'role-manager',
          orgId: 'org-1',
        ),
      ).called(1);
      final state = container.read(userProfileNotifierProvider);
      expect(state.teamMembers.single.role, 'Manager');
      expect(state.error, isNull);
    });

    test('shows an error and sends nothing for an unknown role', () async {
      final container = await loaded();

      await container
          .read(userProfileNotifierProvider.notifier)
          .updateMember(_owner.copyWith(role: 'Ghost'));

      verifyNever(
        () => repo.updateMember(
          any(),
          roleId: any(named: 'roleId'),
          orgId: any(named: 'orgId'),
        ),
      );
      final state = container.read(userProfileNotifierProvider);
      expect(state.error, isNotNull);
      expect(state.isSaving, isFalse);
      expect(state.teamMembers.single.role, 'Owner');
    });
  });
}
