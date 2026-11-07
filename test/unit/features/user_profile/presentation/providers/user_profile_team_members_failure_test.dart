import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockRepo extends Mock implements UserProfileRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

class _Workspaces extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'A', name: 'WS A', avatar: ''),
  );
}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    final storage = _MockStorage();
    locator.registerSingleton<SecureStorageService>(storage);
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    Future<Result<T>> failed<T>() async =>
        Failure<T>(const ApiFailure(message: 'unavailable'));
    when(() => repo.getAccount()).thenAnswer((_) => failed());
    when(() => repo.getSecuritySessions()).thenAnswer((_) => failed());
    when(() => repo.getRolesAndPermissions()).thenAnswer((_) => failed());
    when(() => repo.getBillingInfo()).thenAnswer((_) => failed());
    when(
      () => repo.getNotificationPreferences(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(() => repo.getOrganization(orgId: any(named: 'orgId'))).thenAnswer(
      (_) async => const Success(
        OrganizationProfile(
          id: 'A',
          name: 'Org A',
          natureOfBusiness: 'Design',
          country: 'Nigeria',
        ),
      ),
    );
  });

  tearDown(() async => locator.reset());

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [
        userProfileRepositoryProvider.overrideWithValue(repo),
        workspaceProvider.overrideWith(_Workspaces.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(userProfileNotifierProvider, (_, _) {});
    return container;
  }

  test(
    'a failed member load is recorded and the rest of the profile still loads',
    () async {
      when(
        () => repo.getTeamMembers(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => const Failure(ApiFailure(message: 'down')));

      final profile = container();
      await pumpEventQueue();

      final state = profile.read(userProfileNotifierProvider);
      expect(state.teamMembersLoadFailed, isTrue);
      expect(state.teamMembers, isEmpty);
      expect(state.organization?.name, 'Org A');
    },
  );

  test('a retry that succeeds clears the failure', () async {
    var attempts = 0;
    when(() => repo.getTeamMembers(orgId: any(named: 'orgId'))).thenAnswer((
      _,
    ) async {
      attempts++;
      return attempts == 1
          ? const Failure(ApiFailure(message: 'down'))
          : const Success([
              TeamMember(
                id: 'u-1',
                email: 'ada@example.com',
                role: 'User',
                dateJoined: '',
                status: TeamMemberStatus.active,
                name: 'Ada',
              ),
            ]);
    });

    final profile = container();
    await pumpEventQueue();
    expect(
      profile.read(userProfileNotifierProvider).teamMembersLoadFailed,
      isTrue,
    );

    await profile.read(userProfileNotifierProvider.notifier).load();

    final state = profile.read(userProfileNotifierProvider);
    expect(state.teamMembersLoadFailed, isFalse);
    expect(state.teamMembers.single.name, 'Ada');
  });
}
