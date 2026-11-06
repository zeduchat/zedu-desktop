import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockUserProfileRepository extends Mock implements UserProfileRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class _TestWorkspaceNotifier extends WorkspaceNotifier {
  _TestWorkspaceNotifier(this._selected);

  final String? _selected;

  @override
  WorkspaceState build() {
    return WorkspaceState(
      selectedWorkspace: _selected == null
          ? null
          : Workspace(id: _selected, name: 'Workspace', avatar: ''),
    );
  }
}

Future<Result<T>> _failed<T>() async {
  return Failure<T>(const ApiFailure(message: 'unavailable'));
}

const _alice = TeamMember(
  id: 'u1',
  email: 'alice@zedu.chat',
  role: 'User',
  dateJoined: '',
  status: TeamMemberStatus.active,
  name: 'Alice',
);

void main() {
  group('UserProfileNotifier.fetchOrganisationMembers', () {
    late MockUserProfileRepository repo;

    setUp(() {
      repo = MockUserProfileRepository();
      final storage = MockSecureStorageService();
      locator.registerSingleton<SecureStorageService>(storage);
      when(() => storage.readData(any())).thenAnswer((_) async => null);

      // The notifier loads the profile as soon as it is built.
      when(() => repo.getAccount()).thenAnswer((_) => _failed());
      when(() => repo.getSecuritySessions()).thenAnswer((_) => _failed());
      when(
        () => repo.getRolesAndPermissions(orgId: any(named: 'orgId')),
      ).thenAnswer((_) => _failed());
      when(() => repo.getBillingInfo()).thenAnswer((_) => _failed());
      when(
        () => repo.getNotificationPreferences(orgId: any(named: 'orgId')),
      ).thenAnswer((_) => _failed());
      when(
        () => repo.getOrganization(orgId: any(named: 'orgId')),
      ).thenAnswer((_) => _failed());
    });

    tearDown(() async {
      await locator.reset();
    });

    // Builds the notifier, lets its own profile load finish, then forgets the
    // calls it made so a test sees only what fetchOrganisationMembers does.
    Future<UserProfileNotifier> buildNotifier(String? selectedOrgId) async {
      final container = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repo),
          workspaceProvider.overrideWith(
            () => _TestWorkspaceNotifier(selectedOrgId),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(userProfileNotifierProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      clearInteractions(repo);
      return container.read(userProfileNotifierProvider.notifier);
    }

    test('returns the members of the selected organisation only', () async {
      when(
        () => repo.getTeamMembers(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => const Success<List<TeamMember>>([_alice]));
      final notifier = await buildNotifier('org-1');

      final members = await notifier.fetchOrganisationMembers();

      expect(members, [_alice]);
      verify(() => repo.getTeamMembers(orgId: 'org-1')).called(1);
    });

    test('returns nobody when the members cannot be loaded', () async {
      when(
        () => repo.getTeamMembers(orgId: any(named: 'orgId')),
      ).thenAnswer((_) => _failed());
      final notifier = await buildNotifier('org-1');

      expect(await notifier.fetchOrganisationMembers(), isEmpty);
    });

    test(
      'returns nobody, without a request, when no workspace is selected',
      () async {
        when(
          () => repo.getTeamMembers(orgId: any(named: 'orgId')),
        ).thenAnswer((_) async => const Success<List<TeamMember>>([_alice]));
        final notifier = await buildNotifier(null);

        expect(await notifier.fetchOrganisationMembers(), isEmpty);
        verifyNever(() => repo.getTeamMembers(orgId: any(named: 'orgId')));
      },
    );
  });
}
