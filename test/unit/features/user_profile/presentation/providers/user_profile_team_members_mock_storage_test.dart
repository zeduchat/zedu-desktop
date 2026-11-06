import 'dart:async';
import 'dart:convert';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockRepo extends Mock implements UserProfileRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

const _orgId = 'A';

Workspace _ws(String id) => Workspace(id: id, name: 'WS $id', avatar: '');

class _Workspaces extends WorkspaceNotifier {
  @override
  WorkspaceState build() => WorkspaceState(selectedWorkspace: _ws(_orgId));
}

TeamMember _member(String id, String name) => TeamMember(
  id: id,
  email: '$id@example.com',
  role: 'User',
  name: name,
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
);

/// What an earlier mock-mode run left in secure storage for this workspace.
String _persistedMockMembers() => jsonEncode([
  {
    'id': 'mock-1',
    'email': 'mock@example.com',
    'role': 'Admin',
    'name': 'Mock Member',
    'avatar_url': null,
    'date_joined': '2026-02-02',
    'status': 'active',
  },
]);

void main() {
  late _MockRepo repo;
  late _MockStorage storage;

  setUp(() {
    repo = _MockRepo();
    storage = _MockStorage();
    locator.registerSingleton<SecureStorageService>(storage);
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    when(
      () => storage.readData('mock_team_members_$_orgId'),
    ).thenAnswer((_) async => _persistedMockMembers());

    when(
      () => repo.getAccount(),
    ).thenAnswer((_) async => Success(ProfileAccount.empty()));
    when(
      () => repo.getNotificationPreferences(orgId: any(named: 'orgId')),
    ).thenAnswer((_) async => Success(NotificationPreferences.empty()));
    when(
      () => repo.getSecuritySessions(),
    ).thenAnswer((_) async => const Success(<SecuritySession>[]));
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
    // The API's answer is the real team.
    when(
      () => repo.getTeamMembers(orgId: any(named: 'orgId')),
    ).thenAnswer((_) async => Success([_member('real-1', 'Ada')]));
    when(
      () => repo.getRolesAndPermissions(orgId: any(named: 'orgId')),
    ).thenAnswer((_) async => const Success(<RolePermission>[]));
    when(
      () => repo.getBillingInfo(),
    ).thenAnswer((_) async => Success(BillingInfo.empty()));
  });

  tearDown(() async => locator.reset());

  void useMockData({required bool enabled}) {
    if (locator.isRegistered<AppConfig>()) locator.unregister<AppConfig>();
    locator.registerSingleton<AppConfig>(
      AppConfig(apiBaseUrl: 'http://test/', usesMockData: enabled),
    );
  }

  Future<List<TeamMember>> loadedTeamMembers() async {
    final container = ProviderContainer(
      overrides: [
        userProfileRepositoryProvider.overrideWithValue(repo),
        workspaceProvider.overrideWith(_Workspaces.new),
      ],
    );
    addTearDown(container.dispose);

    final completer = Completer<UserProfileState>();
    final subscription = container.listen<UserProfileState>(
      userProfileNotifierProvider,
      (_, next) {
        if (!next.isLoading && !completer.isCompleted) completer.complete(next);
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final state = await completer.future.timeout(const Duration(seconds: 5));
    return state.teamMembers;
  }

  test('stored mock members are ignored outside mock mode', () async {
    useMockData(enabled: false);

    final members = await loadedTeamMembers();

    expect(members.map((m) => m.id), ['real-1']);
    expect(members.single.name, 'Ada');
  });

  test('stored mock members are still used in mock mode', () async {
    useMockData(enabled: true);

    final members = await loadedTeamMembers();

    expect(members.map((m) => m.id), ['mock-1']);
    expect(members.single.name, 'Mock Member');
  });
}
