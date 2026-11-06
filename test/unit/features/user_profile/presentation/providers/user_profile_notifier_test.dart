import 'dart:async';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockUserProfileRepository extends Mock implements UserProfileRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(
      id: 'org-1',
      name: 'Test Workspace',
      avatar: '',
    ),
  );
}

/// Builds an [ApiBaseService] whose Dio is intercepted to reply with the
/// canned roles payload so the notifier's role lookup can be verified
/// end-to-end without a real network. Outgoing requests are captured too.
class _RecordingApi {
  _RecordingApi({
    required this.config,
    required List<Map<String, dynamic>> roles,
  }) {
    final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: options.path.contains('/roles')
                  ? {'data': roles}
                  : const {
                      'data': {'invitations': <dynamic>[]},
                    },
            ),
          );
        },
      ),
    );
    service = ApiBaseService(config: config, dio: dio);
  }

  final AppConfig config;
  final List<RequestOptions> requests = [];
  late final ApiBaseService service;
}

/// Roles as returned by `GET /organisations/{orgId}/roles`.
const _rolesResponse = [
  {'id': 'role-admin', 'name': 'Administrator'},
  {'id': 'role-manager', 'name': 'Manager'},
  {'id': 'role-user', 'name': 'User'},
];

void main() {
  group('UserProfileNotifier.updateAccount', () {
    late MockUserProfileRepository repository;

    setUpAll(() => registerFallbackValue(ProfileAccount.empty()));

    setUp(() {
      repository = MockUserProfileRepository();
      when(
        () => repository.updateAccount(any()),
      ).thenAnswer((_) async => Success(ProfileAccount.empty()));
    });

    // The profile load started in build() still fails with the
    // uninitialized-provider error tracked in #51, so it's ignored here; the
    // account is then the placeholder the edit form opens with.
    Future<void> ignoringProfileLoadError(Future<void> Function() body) {
      final done = Completer<void>();
      runZonedGuarded(
        () => body().then(done.complete, onError: done.completeError),
        (error, stack) {
          if (error is! StateError) done.completeError(error, stack);
        },
      );
      return done.future;
    }

    test('sends only the edited fields and shows only what was saved', () {
      return ignoringProfileLoadError(() async {
        final container = ProviderContainer(
          overrides: [
            userProfileRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(userProfileNotifierProvider.notifier);
        final placeholder = ProfileAccount.empty();

        await notifier.updateAccount(
          placeholder.copyWith(
            phoneNumber: '+2348012345678',
            email: 'me@zedu.chat',
          ),
        );

        final sent =
            verify(() => repository.updateAccount(captureAny())).captured.single
                as ProfileAccount;
        expect(sent.name, '');
        expect(sent.phoneNumber, '+2348012345678');

        final shown = container.read(userProfileNotifierProvider).account!;
        expect(shown.phoneNumber, '+2348012345678');
        expect(shown.name, placeholder.name);
        expect(shown.email, placeholder.email);
      });
    });

    test('changePassword returns a failure for the dialog to show', () {
      return ignoringProfileLoadError(() async {
        final container = ProviderContainer(
          overrides: [
            userProfileRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        when(
          () => repository.changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenAnswer(
          (_) async => const Failure<void>(
            ApiFailure(message: 'Wrong', kind: ApiFailureKind.client),
          ),
        );

        final result = await container
            .read(userProfileNotifierProvider.notifier)
            .changePassword(currentPassword: 'a', newPassword: 'b');

        expect(result, isA<Failure<void>>());
        final state = container.read(userProfileNotifierProvider);
        expect(state.isSaving, isFalse);
        expect(state.error, isNull);
      });
    });

    test('changePassword returns success and reports it on the page', () {
      return ignoringProfileLoadError(() async {
        final container = ProviderContainer(
          overrides: [
            userProfileRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        when(
          () => repository.changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenAnswer((_) async => const Success<void>(null));

        final result = await container
            .read(userProfileNotifierProvider.notifier)
            .changePassword(currentPassword: 'a', newPassword: 'b');

        expect(result, isA<Success<void>>());
        expect(
          container.read(userProfileNotifierProvider).successMessage,
          'Password updated successfully.',
        );
      });
    });
  });

  group('UserProfileNotifier.updateNotificationPreferences', () {
    late MockUserProfileRepository repository;
    late ProviderContainer container;

    final edited = NotificationPreferences.empty().copyWith(
      mode: NotificationMode.mentionsOnly,
    );

    setUp(() {
      repository = MockUserProfileRepository();

      final storage = MockSecureStorageService();
      when(() => storage.readData(any())).thenAnswer((_) async => null);
      if (locator.isRegistered<SecureStorageService>()) {
        locator.unregister<SecureStorageService>();
      }
      locator.registerSingleton<SecureStorageService>(storage);
      if (locator.isRegistered<AppConfig>()) locator.unregister<AppConfig>();
      locator.registerSingleton<AppConfig>(
        const AppConfig(apiBaseUrl: 'http://test/', usesMockData: false),
      );

      when(
        () => repository.getAccount(),
      ).thenAnswer((_) async => Success(ProfileAccount.empty()));
      when(
        () => repository.getNotificationPreferences(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => Success(NotificationPreferences.empty()));
      when(
        () => repository.getSecuritySessions(),
      ).thenAnswer((_) async => const Success(<SecuritySession>[]));
      when(
        () => repository.getOrganization(orgId: any(named: 'orgId')),
      ).thenAnswer(
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
        () => repository.getTeamMembers(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => const Success(<TeamMember>[]));
      when(
        () => repository.getRolesAndPermissions(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => const Success(<RolePermission>[]));
      when(
        () => repository.getBillingInfo(),
      ).thenAnswer((_) async => Success(BillingInfo.empty()));

      container = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
    });

    tearDown(() {
      locator.unregister<SecureStorageService>();
      locator.unregister<AppConfig>();
    });

    Future<UserProfileState> loaded() async {
      final completer = Completer<UserProfileState>();
      final subscription = container.listen<UserProfileState>(
        userProfileNotifierProvider,
        (_, next) {
          if (!next.isLoading && !completer.isCompleted) {
            completer.complete(next);
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      return completer.future.timeout(const Duration(seconds: 5));
    }

    void stubSave(Future<Result<NotificationPreferences>> Function() answer) {
      when(
        () => repository.updateNotificationPreferences(
          orgId: any(named: 'orgId'),
          preferences: edited,
        ),
      ).thenAnswer((_) => answer());
    }

    test('makes the saved preferences the new baseline', () async {
      stubSave(() async => Success(edited));
      await loaded();
      final notifier = container.read(userProfileNotifierProvider.notifier);

      await notifier.updateNotificationPreferences(edited);

      final state = container.read(userProfileNotifierProvider);
      expect(state.notifications, edited);
      expect(state.isSaving, isFalse);
      expect(state.error, isNull);
    });

    test('keeps the old baseline and reports a failed save', () async {
      stubSave(
        () async => const Failure(
          ApiFailure(message: 'Nope', kind: ApiFailureKind.client),
        ),
      );
      await loaded();
      final notifier = container.read(userProfileNotifierProvider.notifier);

      await notifier.updateNotificationPreferences(edited);

      final state = container.read(userProfileNotifierProvider);
      expect(state.notifications, NotificationPreferences.empty());
      expect(state.isSaving, isFalse);
      expect(state.error, 'Nope');
    });

    test('ignores a second save while one is running', () async {
      final pending = Completer<Result<NotificationPreferences>>();
      stubSave(() => pending.future);
      await loaded();
      final notifier = container.read(userProfileNotifierProvider.notifier);

      final first = notifier.updateNotificationPreferences(edited);
      await notifier.updateNotificationPreferences(edited);
      pending.complete(Success(edited));
      await first;

      verify(
        () => repository.updateNotificationPreferences(
          orgId: any(named: 'orgId'),
          preferences: edited,
        ),
      ).called(1);
    });
  });

  group('UserProfileNotifier.inviteMember', () {
    late MockUserProfileRepository repository;
    late _RecordingApi recorder;
    String? lastInviteEmail;
    String? lastInviteRoleId;
    String? lastInviteOrgId;

    setUp(() {
      registerFallbackValue('');
      repository = MockUserProfileRepository();

      locator.registerSingleton<AppConfig>(
        AppConfig(apiBaseUrl: 'https://api.example.com', usesMockData: false),
      );
      final mockStorage = MockSecureStorageService();
      when(() => mockStorage.readData(any())).thenAnswer((_) async => null);
      locator.registerSingleton<SecureStorageService>(mockStorage);

      // Stub every repository call made by the background load() microtask
      // scheduled in build() so it completes without errors.
      when(
        () => repository.getAccount(),
      ).thenAnswer((_) async => Success(ProfileAccount.empty()));
      when(
        () => repository.getNotificationPreferences(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => Success(NotificationPreferences.empty()));
      when(
        () => repository.getSecuritySessions(),
      ).thenAnswer((_) async => Success(<SecuritySession>[]));
      when(
        () => repository.getOrganization(orgId: any(named: 'orgId')),
      ).thenAnswer(
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
        () => repository.getTeamMembers(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => Success(<TeamMember>[]));
      when(
        () => repository.getRolesAndPermissions(orgId: any(named: 'orgId')),
      ).thenAnswer((_) async => Success(<RolePermission>[]));
      when(
        () => repository.getBillingInfo(),
      ).thenAnswer((_) async => Success(BillingInfo.empty()));
    });

    tearDown(() async {
      await locator.reset();
    });

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// Waits for the background [load] microtask (scheduled in [build])
    /// to finish before interacting with the notifier.
    Future<void> waitForLoad(ProviderContainer container) async {
      while (container.read(userProfileNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    void stubRoles(List<Map<String, dynamic>> roleRecords) {
      recorder = _RecordingApi(
        config: locator<AppConfig>(),
        roles: roleRecords,
      );
      locator.registerSingleton<ApiBaseService>(recorder.service);
    }

    void stubInvite(Result<TeamMember> result) {
      when(
        () => repository.inviteMember(
          email: any(named: 'email'),
          role: any(named: 'role'),
          orgId: any(named: 'orgId'),
        ),
      ).thenAnswer((invocation) async {
        lastInviteEmail = invocation.namedArguments[#email] as String?;
        lastInviteRoleId = invocation.namedArguments[#role] as String?;
        lastInviteOrgId = invocation.namedArguments[#orgId] as String?;
        return result;
      });
    }

    Future<void> invite(
      ProviderContainer container, {
      String role = 'User',
      String email = 'invitee@example.com',
    }) {
      return container
          .read(userProfileNotifierProvider.notifier)
          .inviteMember(email: email, role: role);
    }

    test(
      'maps the selected role label to the matching backend role id',
      () async {
        stubRoles(_rolesResponse);
        stubInvite(
          Success(
            const TeamMember(
              id: 'new-member',
              email: 'invitee@example.com',
              role: 'role-manager',
              dateJoined: '2026-01-01',
              status: TeamMemberStatus.pending,
            ),
          ),
        );

        final container = makeContainer();
        await waitForLoad(container);
        await invite(container, role: 'Manager');

        expect(
          lastInviteRoleId,
          equals('role-manager'),
          reason:
              'the selected role must map to its backend UUID, not a fixed '
              'or arbitrary role',
        );
        expect(lastInviteEmail, equals('invitee@example.com'));
        expect(lastInviteOrgId, equals('org-1'));

        final state = container.read(userProfileNotifierProvider);
        expect(state.teamMembers.single.role, equals('Manager'));
        expect(
          state.teamMembers.single.role,
          isNot(equals('role-manager')),
          reason: 'the table must show the role name, not the UUID',
        );
      },
    );

    test(
      'sends a different role id when a different role is selected',
      () async {
        stubRoles(_rolesResponse);
        stubInvite(
          Success(
            const TeamMember(
              id: 'new-member',
              email: 'invitee@example.com',
              role: 'role-admin',
              dateJoined: '2026-01-01',
              status: TeamMemberStatus.pending,
            ),
          ),
        );

        final container = makeContainer();
        await waitForLoad(container);
        await invite(container, role: 'Administrator');

        expect(lastInviteRoleId, equals('role-admin'));
        expect(
          container.read(userProfileNotifierProvider).teamMembers.single.role,
          equals('Administrator'),
        );
      },
    );

    test('accepts a role id selection without a name lookup', () async {
      stubRoles(_rolesResponse);
      stubInvite(
        Success(
          const TeamMember(
            id: 'new-member',
            email: 'invitee@example.com',
            role: 'role-user',
            dateJoined: '2026-01-01',
            status: TeamMemberStatus.pending,
          ),
        ),
      );

      final container = makeContainer();
      await waitForLoad(container);
      await invite(container, role: 'role-user');

      expect(lastInviteRoleId, equals('role-user'));
    });

    test('stores the human-readable name, never the backend UUID, after a '
        'successful invitation', () async {
      stubRoles(_rolesResponse);
      stubInvite(
        Success(
          const TeamMember(
            id: 'new-member',
            email: 'invitee@example.com',
            role: '019700d8-9085-7f7b-839a-fcbd08b9e26d',
            dateJoined: '2026-01-01',
            status: TeamMemberStatus.pending,
          ),
        ),
      );

      final container = makeContainer();
      await waitForLoad(container);
      await invite(container, role: 'User');

      final state = container.read(userProfileNotifierProvider);
      expect(state.teamMembers, hasLength(1));
      expect(
        state.teamMembers.first.role,
        equals('User'),
        reason:
            'role should be the human-readable name passed to '
            'inviteMember, not the UUID returned by the backend',
      );
      expect(state.teamMembers.first.email, equals('invitee@example.com'));
      expect(state.teamMembers.first.id, equals('new-member'));
      expect(state.isSaving, isFalse);
      expect(state.successMessage, isNotNull);
    });

    test(
      'rejects an unknown role without calling the invite endpoint',
      () async {
        stubRoles(_rolesResponse);
        stubInvite(
          Success(
            const TeamMember(
              id: 'new-member',
              email: 'invitee@example.com',
              role: 'role-user',
              dateJoined: '2026-01-01',
              status: TeamMemberStatus.pending,
            ),
          ),
        );

        final container = makeContainer();
        await waitForLoad(container);
        await invite(container, role: 'Owner');

        expect(
          recorder.requests.any(
            (request) => request.path.contains('organisations/org-1/roles'),
          ),
          isTrue,
          reason: 'the notifier must look up the organisation roles',
        );
        expect(
          recorder.requests.where(
            (request) => request.path.contains('/invite'),
          ),
          isEmpty,
          reason: 'an unresolvable role must not be sent to the backend',
        );

        final state = container.read(userProfileNotifierProvider);
        expect(state.teamMembers, isEmpty);
        expect(state.isSaving, isFalse);
        expect(state.error, isNotNull);
        verifyNever(
          () => repository.inviteMember(
            email: any(named: 'email'),
            role: any(named: 'role'),
            orgId: any(named: 'orgId'),
          ),
        );
      },
    );

    test('fails visibly when the roles endpoint returns no roles', () async {
      stubRoles(const []);
      stubInvite(
        Success(
          const TeamMember(
            id: 'new-member',
            email: 'invitee@example.com',
            role: 'role-user',
            dateJoined: '2026-01-01',
            status: TeamMemberStatus.pending,
          ),
        ),
      );

      final container = makeContainer();
      await waitForLoad(container);
      await invite(container, role: 'User');

      final state = container.read(userProfileNotifierProvider);
      expect(state.teamMembers, isEmpty);
      expect(state.error, isNotNull);
      expect(state.isSaving, isFalse);
    });

    test('does not add a member when the invitation fails', () async {
      stubRoles(_rolesResponse);
      stubInvite(
        const Failure<TeamMember>(
          ApiFailure(message: 'Unable to invite member'),
        ),
      );

      final container = makeContainer();
      await waitForLoad(container);
      await invite(container, role: 'User');

      final state = container.read(userProfileNotifierProvider);
      expect(state.teamMembers, isEmpty);
      expect(state.isSaving, isFalse);
      expect(state.error, isNotNull);
    });
  });
}
