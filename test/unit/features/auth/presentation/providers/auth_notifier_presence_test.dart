import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockAuthInterceptor extends Mock implements AuthInterceptor {}

User _buildUser({
  String id = 'user-1',
  bool online = true,
  String org = 'org-1',
  String firstName = 'Test',
}) => User(
  id: id,
  firstName: firstName,
  lastName: 'User',
  email: 'test@example.com',
  phone: '+1234567890',
  username: 'testuser',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026, 1, 1),
  currentOrg: org,
  currentOrganisationSlug: 'slug-$org',
  avatarUrl: '',
  defaultAvatarUrl: '',
  status: UserStatus(online: online),
);

UserModel _modelUser({bool online = true}) {
  final planDetails = PlanDetailsModel(
    id: 'plan-1',
    name: 'Free',
    description: '',
    benefits: const [],
    fee: 0,
    maxChannels: 0,
    maxUsers: 0,
    maxNotifications: 0,
    canUpgradeNotifications: false,
    canAddUnlimitedChannels: false,
    canAddUnlimitedUsers: false,
    isForIndividuals: false,
    isForSmallBusiness: false,
    isForLargeEnterprise: false,
    unlimitedAiCoWorkers: false,
    createYourOwnAiCoWorkers: false,
    aiCreditsPurchasable: true,
    maxCallDuration: 0,
    maxBuzzParticipants: 0,
    maxActiveCalls: 0,
    callRecordsAvailable: false,
    transcriptAvailable: false,
    advancedControls: false,
    advancedControlsUser: false,
    createdAt: DateTime(2026, 1, 1),
    credits: 0,
    updatedAt: DateTime(2026, 1, 1),
  );
  final organisation = OrganisationModel(
    id: 'org-1',
    name: 'Org',
    description: '',
    email: 'org@example.com',
    type: '',
    location: '',
    country: '',
    ownerId: 'owner-1',
    logoUrl: '',
    creditBalance: 10,
    channelsCount: 0,
    totalMessagesCount: 0,
    orgRoles: const [],
    pinned: false,
    users: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    channels: null,
    subscriptionPlanId: 'plan-1',
    stripeCustomerId: '',
    orgPlanId: 'org-plan-1',
    organisationPlan: OrganisationPlanModel(
      startedAt: DateTime(2026, 1, 1),
      endedAt: DateTime(2027, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      planDetails: planDetails,
    ),
    organisationSlug: 'test-org',
    userRole: const UserRoleModel(roleId: 'role-1', roleName: 'member'),
  );
  return UserModel(
    id: 'user-1',
    firstName: 'Test',
    lastName: 'User',
    fullname: 'Test User',
    email: 'test@example.com',
    phone: '+1234567890',
    username: 'testuser',
    isVerified: true,
    isOnboarded: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    avatarUrl: '',
    currentOrg: 'org-1',
    currentOrganisationSlug: 'test-org',
    defaultAvatarUrl: '',
    expiresIn: DateTime(2027, 1, 1),
    isActive: true,
    online: online,
    organisation: organisation,
    profileUpdated: false,
    userId: 'user-1',
  );
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void _stubSetPresence(MockAuthRepository repo, Future<Result<void>> future) {
  when(
    () => repo.setPresence(online: any(named: 'online')),
  ).thenAnswer((_) => future);
}

void _stubChangeStatus(MockAuthRepository repo, Future<Result<void>> future) {
  when(
    () => repo.changeStatus(
      icon: any(named: 'icon'),
      text: any(named: 'text'),
      pauseNotifications: any(named: 'pauseNotifications'),
      statusTimeout: any(named: 'statusTimeout'),
      clearStatus: any(named: 'clearStatus'),
      online: any(named: 'online'),
    ),
  ).thenAnswer((_) => future);
}

void _stubLogin(MockAuthRepository repo, User user) {
  when(
    () => repo.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer(
    (_) async => Success(
      AuthSession(
        user: user,
        accessToken: 'token-2',
        accessTokenExpiresIn: DateTime.now().add(const Duration(hours: 1)),
      ),
    ),
  );
}

MockSecureStorageService _storage() =>
    locator<SecureStorageService>() as MockSecureStorageService;

/// Wires the real AuthNotifier with a mocked repository and storage, and
/// restores an authenticated session for [seedUser] before destructuring.
Future<(ProviderContainer, AuthNotifier, MockAuthRepository)> _buildSession({
  User? seedUser,
}) async {
  final repo = MockAuthRepository();
  final storage = MockSecureStorageService();
  locator.registerSingleton<SecureStorageService>(storage);
  locator.registerSingleton<AuthInterceptor>(MockAuthInterceptor());
  addTearDown(locator.reset);

  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);

  when(() => storage.getAccessToken()).thenAnswer((_) async => 'token');
  when(
    () => repo.getCurrentUser(),
  ).thenAnswer((_) async => Success(seedUser ?? _buildUser()));

  final notifier = container.read(authNotifierProvider.notifier);
  await _flushAsync();

  expect(container.read(authNotifierProvider).status, AuthStatus.authenticated);
  return (container, notifier, repo);
}

void main() {
  group('AuthNotifier.toggleOnlineStatus', () {
    test('toggles Active → Away through the presence-only endpoint', () async {
      final (container, notifier, repo) = await _buildSession();
      _stubSetPresence(repo, Future.value(const Success(null)));

      final outcome = await notifier.toggleOnlineStatus();

      expect(outcome, isA<PresenceConfirmed>());
      final state = container.read(authNotifierProvider);
      expect(state.user?.status.online, isFalse);
      expect(state.error, isNull);
      expect(container.read(userMenuStateProvider).isAway, isTrue);
      verify(() => repo.setPresence(online: false)).called(1);
      verifyNever(
        () => repo.changeStatus(
          icon: any(named: 'icon'),
          text: any(named: 'text'),
          pauseNotifications: any(named: 'pauseNotifications'),
          statusTimeout: any(named: 'statusTimeout'),
          clearStatus: any(named: 'clearStatus'),
          online: any(named: 'online'),
        ),
      );
    });

    test('toggles Away → Active on a second confirmed toggle', () async {
      final (container, notifier, repo) = await _buildSession(
        seedUser: _buildUser(online: false),
      );
      _stubSetPresence(repo, Future.value(const Success(null)));

      final outcome = await notifier.toggleOnlineStatus();

      expect(outcome, isA<PresenceConfirmed>());
      expect(container.read(authNotifierProvider).user?.status.online, isTrue);
      expect(container.read(userMenuStateProvider).isAway, isFalse);
      verify(() => repo.setPresence(online: true)).called(1);
    });

    test(
      'keeps presence and surfaces the error when the request fails',
      () async {
        final (container, notifier, repo) = await _buildSession();
        _stubSetPresence(
          repo,
          Future.value(
            const Failure<void>(
              ApiFailure(
                message: 'Failed to update user profile',
                kind: ApiFailureKind.client,
                statusCode: 400,
              ),
            ),
          ),
        );

        final outcome = await notifier.toggleOnlineStatus();

        expect(outcome, isA<PresenceFailed>());
        final failed = outcome as PresenceFailed;
        expect(failed.message, 'Failed to update user profile');
        final state = container.read(authNotifierProvider);
        expect(state.user?.status.online, isTrue);
        expect(state.error, 'Failed to update user profile');
        expect(container.read(userMenuStateProvider).isAway, isFalse);
      },
    );

    test('skips a duplicate toggle without fabricating an error', () async {
      final (container, notifier, repo) = await _buildSession();

      final gate = Completer<Result<void>>();
      _stubSetPresence(repo, gate.future);
      final first = notifier.toggleOnlineStatus();
      await _flushAsync();

      final second = await notifier.toggleOnlineStatus();

      expect(second, isA<PresenceSkipped>());
      expect(container.read(authNotifierProvider).error, isNull);
      verify(() => repo.setPresence(online: any(named: 'online'))).called(1);

      gate.complete(const Success(null));
      expect(await first, isA<PresenceConfirmed>());
    });

    test(
      'discards a stale confirmation after the signed-in user changed',
      () async {
        final (container, notifier, repo) = await _buildSession();

        when(() => _storage().saveAccessToken(any())).thenAnswer((_) async {});
        _stubLogin(repo, _buildUser(id: 'user-2'));

        final gate = Completer<Result<void>>();
        _stubSetPresence(repo, gate.future);
        final pending = notifier.toggleOnlineStatus();
        await _flushAsync();

        await notifier.login(
          email: 'other@example.com',
          password: 'Password123',
        );
        expect(container.read(authNotifierProvider).user?.id, 'user-2');

        gate.complete(const Success(null));
        final outcome = await pending;

        expect(outcome, isA<PresenceSkipped>());
        final state = container.read(authNotifierProvider);
        expect(state.user?.id, 'user-2');
        expect(state.user?.status.online, isTrue);
        expect(state.error, isNull);
        expect(container.read(userMenuStateProvider).isAway, isFalse);
      },
    );

    test(
      'discards a stale confirmation after logout and login as the same user',
      () async {
        final (container, notifier, repo) = await _buildSession();

        when(() => _storage().deleteAccessToken()).thenAnswer((_) async {});
        when(() => _storage().saveAccessToken(any())).thenAnswer((_) async {});
        _stubLogin(repo, _buildUser(id: 'user-1'));

        final gate = Completer<Result<void>>();
        _stubSetPresence(repo, gate.future);
        final pending = notifier.toggleOnlineStatus();
        await _flushAsync();

        await notifier.logout();
        await notifier.login(
          email: 'test@example.com',
          password: 'Password123',
        );
        expect(container.read(authNotifierProvider).user?.id, 'user-1');
        // Re-login starts from the persisted presence (online).
        expect(
          container.read(authNotifierProvider).user?.status.online,
          isTrue,
        );

        gate.complete(const Success(null));
        final outcome = await pending;

        // Same account ID, but a different session: the old confirmation
        // must not flip the new session's presence.
        expect(outcome, isA<PresenceSkipped>());
        expect(
          container.read(authNotifierProvider).user?.status.online,
          isTrue,
        );
        expect(container.read(authNotifierProvider).error, isNull);
        expect(container.read(userMenuStateProvider).isAway, isFalse);
      },
    );

    test(
      'discards a stale failure after logout without leaking an error',
      () async {
        final (container, notifier, repo) = await _buildSession();

        when(() => _storage().deleteAccessToken()).thenAnswer((_) async {});

        final gate = Completer<Result<void>>();
        _stubSetPresence(repo, gate.future);
        final pending = notifier.toggleOnlineStatus();
        await _flushAsync();

        await notifier.logout();

        gate.complete(
          const Failure<void>(
            ApiFailure(
              message: 'Failed to update user profile',
              kind: ApiFailureKind.client,
              statusCode: 500,
            ),
          ),
        );
        final outcome = await pending;

        expect(outcome, isA<PresenceSkipped>());
        final state = container.read(authNotifierProvider);
        expect(state.status, AuthStatus.unauthenticated);
        expect(state.error, isNull);
      },
    );

    test('releases the in-flight guard across a session change', () async {
      final (container, notifier, repo) = await _buildSession();

      final storage = _storage();
      when(() => storage.deleteAccessToken()).thenAnswer((_) async {});
      when(() => storage.saveAccessToken(any())).thenAnswer((_) async {});
      _stubLogin(repo, _buildUser(id: 'user-2'));

      final staleGate = Completer<Result<void>>();
      _stubSetPresence(repo, staleGate.future);
      final stale = notifier.toggleOnlineStatus();
      await _flushAsync();

      await notifier.logout();
      await notifier.login(email: 'other@example.com', password: 'Password123');

      // The new session can toggle immediately: the stale request's guard
      // did not carry over.
      _stubSetPresence(repo, Future.value(const Success(null)));
      final outcome = await notifier.toggleOnlineStatus();

      expect(outcome, isA<PresenceConfirmed>());
      expect(container.read(authNotifierProvider).user?.status.online, isFalse);

      staleGate.complete(const Success(null));
      expect(await stale, isA<PresenceSkipped>());
    });

    test(
      'completes safely when the provider is disposed mid-request',
      () async {
        final (container, notifier, repo) = await _buildSession();

        final gate = Completer<Result<void>>();
        _stubSetPresence(repo, gate.future);
        final pending = notifier.toggleOnlineStatus();
        await _flushAsync();

        container.dispose();
        gate.complete(const Success(null));

        // The discarded outcome must not write to the disposed container.
        expect(await pending, isA<PresenceSkipped>());
      },
    );

    test(
      'discards a stale confirmation after an organisation change',
      () async {
        final (container, notifier, repo) = await _buildSession();

        final gate = Completer<Result<void>>();
        _stubSetPresence(repo, gate.future);
        final pending = notifier.toggleOnlineStatus();
        await _flushAsync();

        // Same account, different organisation (e.g. via a refresh).
        when(
          () => repo.getCurrentUser(),
        ).thenAnswer((_) async => Success(_buildUser(org: 'org-2')));
        await notifier.refreshCurrentUser();
        expect(container.read(authNotifierProvider).user?.currentOrg, 'org-2');

        gate.complete(const Success(null));
        final outcome = await pending;

        expect(outcome, isA<PresenceSkipped>());
        final state = container.read(authNotifierProvider);
        expect(state.user?.currentOrg, 'org-2');
        expect(state.user?.status.online, isTrue);
      },
    );

    test(
      'applies presence to the latest user state after a concurrent status change',
      () async {
        final (container, notifier, repo) = await _buildSession();

        final presenceGate = Completer<Result<void>>();
        _stubSetPresence(repo, presenceGate.future);
        _stubChangeStatus(repo, Future.value(const Success(null)));

        final pending = notifier.toggleOnlineStatus();
        await _flushAsync();

        // A custom-status update is requested while the presence request is
        // in flight: it is queued behind it, never sent concurrently.
        final statusChanged = notifier.changeStatus(
          icon: '📅',
          text: 'Commuting',
          timeout: StatusTimeout.thirtyMinutes,
          pauseNotifications: false,
        );
        await _flushAsync();
        verifyNever(
          () => repo.changeStatus(
            icon: any(named: 'icon'),
            text: any(named: 'text'),
            pauseNotifications: any(named: 'pauseNotifications'),
            statusTimeout: any(named: 'statusTimeout'),
            clearStatus: any(named: 'clearStatus'),
            online: any(named: 'online'),
          ),
        );

        presenceGate.complete(const Success(null));
        final outcome = await pending;
        expect(await statusChanged, isTrue);

        // The confirmed presence lands on the LATEST user: the queued custom
        // status is preserved alongside the new online flag, and its server
        // write carried the confirmed presence instead of a stale value.
        expect(outcome, isA<PresenceConfirmed>());
        final status = container.read(authNotifierProvider).user?.status;
        expect(status?.online, isFalse);
        expect(status?.text, 'Commuting');
        expect(status?.emoji, '📅');
        expect(status?.expiresAt, isNotNull);
        verify(
          () => repo.changeStatus(
            icon: '📅',
            text: 'Commuting',
            pauseNotifications: false,
            statusTimeout: '30 minutes',
            clearStatus: false,
            online: false,
          ),
        ).called(1);
      },
    );

    test(
      'queued status writes reach the backend in request order, last intent wins',
      () async {
        final (container, notifier, repo) = await _buildSession();

        final gateA = Completer<Result<void>>();
        final gateB = Completer<Result<void>>();
        final futures = <Future<Result<void>>>[gateA.future, gateB.future];
        // A mocktail verify consumes matched calls, so the send order and
        // payloads are recorded here instead of re-verifying the same calls.
        final sentTexts = <String>[];
        when(
          () => repo.changeStatus(
            icon: any(named: 'icon'),
            text: any(named: 'text'),
            pauseNotifications: any(named: 'pauseNotifications'),
            statusTimeout: any(named: 'statusTimeout'),
            clearStatus: any(named: 'clearStatus'),
            online: any(named: 'online'),
          ),
        ).thenAnswer((invocation) {
          sentTexts.add(invocation.namedArguments[#text] as String);
          return futures.removeAt(0);
        });

        final pendingA = notifier.changeStatus(
          icon: '',
          text: 'First',
          timeout: StatusTimeout.oneHour,
          pauseNotifications: false,
        );
        await _flushAsync();
        final pendingB = notifier.changeStatus(
          icon: '',
          text: 'Second',
          timeout: StatusTimeout.thirtyMinutes,
          pauseNotifications: false,
        );
        await _flushAsync();

        // The second write is not sent until the first response arrives.
        expect(sentTexts, ['First']);

        gateA.complete(const Success(null));
        expect(await pendingA, isTrue);
        await _flushAsync();

        // The older mutation does not apply locally over the newer intent.
        expect(container.read(authNotifierProvider).user?.status.text, isNull);

        gateB.complete(const Success(null));
        expect(await pendingB, isTrue);

        // The backend received First then Second (same order as the client
        // requested them), so its final persisted text is the latest intent.
        expect(sentTexts, ['First', 'Second']);
        verify(
          () => repo.changeStatus(
            icon: '',
            text: 'First',
            pauseNotifications: false,
            statusTimeout: '1 hour',
            clearStatus: false,
            online: true,
          ),
        ).called(1);
        verify(
          () => repo.changeStatus(
            icon: '',
            text: 'Second',
            pauseNotifications: false,
            statusTimeout: '30 minutes',
            clearStatus: false,
            online: true,
          ),
        ).called(1);
        expect(
          container.read(authNotifierProvider).user?.status.text,
          'Second',
        );
        expect(
          container.read(authNotifierProvider).user?.status.online,
          isTrue,
        );
      },
    );

    test(
      'clearStatus keeps presence and pins the corrected never-expire value',
      () async {
        final (container, notifier, repo) = await _buildSession(
          seedUser: _buildUser(online: false),
        );
        _stubChangeStatus(repo, Future.value(const Success(null)));

        final cleared = await notifier.clearStatus();

        expect(cleared, isTrue);
        verify(
          () => repo.changeStatus(
            icon: '',
            text: '',
            pauseNotifications: false,
            statusTimeout: 'dont-clear',
            clearStatus: true,
            online: false,
          ),
        ).called(1);
        final status = container.read(authNotifierProvider).user?.status;
        expect(status?.text, isNull);
        expect(status?.emoji, isNull);
        expect(status?.online, isFalse);
      },
    );

    test(
      'login syncs the menu presence indicator from the session user',
      () async {
        final (container, notifier, repo) = await _buildSession();

        when(() => _storage().saveAccessToken(any())).thenAnswer((_) async {});
        _stubLogin(repo, _buildUser(online: false));

        await notifier.login(
          email: 'test@example.com',
          password: 'Password123',
        );

        expect(
          container.read(authNotifierProvider).user?.status.online,
          isFalse,
        );
        expect(container.read(userMenuStateProvider).isAway, isTrue);
      },
    );
  });

  group('AuthNotifier.refreshCurrentUser presence coordination', () {
    test(
      'a stale refresh does not revert confirmed presence or split indicators',
      () async {
        final (container, notifier, repo) = await _buildSession();

        // The refresh snapshot is captured before the toggle confirms.
        final gate = Completer<Result<User>>();
        when(() => repo.getCurrentUser()).thenAnswer((_) => gate.future);
        final refresh = notifier.refreshCurrentUser();

        _stubSetPresence(repo, Future.value(const Success(null)));
        expect(await notifier.toggleOnlineStatus(), isA<PresenceConfirmed>());
        expect(
          container.read(authNotifierProvider).user?.status.online,
          isFalse,
        );

        // The pre-toggle (stale, Active) snapshot arrives afterwards.
        gate.complete(Success(_buildUser()));
        await refresh;

        // The confirmed Away survives, and both indicators agree.
        expect(
          container.read(authNotifierProvider).user?.status.online,
          isFalse,
        );
        expect(container.read(userMenuStateProvider).isAway, isTrue);
      },
    );

    test(
      'a refresh overlapping an in-flight toggle keeps the confirmed presence and fresh profile fields',
      () async {
        final (container, notifier, repo) = await _buildSession();

        final presenceGate = Completer<Result<void>>();
        _stubSetPresence(repo, presenceGate.future);
        final pendingToggle = notifier.toggleOnlineStatus();
        await _flushAsync();

        // The refresh starts while the toggle is still in flight.
        final refreshGate = Completer<Result<User>>();
        when(() => repo.getCurrentUser()).thenAnswer((_) => refreshGate.future);
        final refresh = notifier.refreshCurrentUser();

        presenceGate.complete(const Success(null));
        expect(await pendingToggle, isA<PresenceConfirmed>());

        refreshGate.complete(Success(_buildUser(firstName: 'Refreshed')));
        await refresh;

        final state = container.read(authNotifierProvider);
        // Merged: fresh profile data + the locally confirmed presence.
        expect(state.user?.firstName, 'Refreshed');
        expect(state.user?.status.online, isFalse);
        expect(container.read(userMenuStateProvider).isAway, isTrue);
      },
    );

    test(
      'a non-overlapping refresh adopts a legitimately changed server presence',
      () async {
        final (container, notifier, repo) = await _buildSession();

        // No mutations overlap: the server snapshot is authoritative.
        when(
          () => repo.getCurrentUser(),
        ).thenAnswer((_) async => Success(_buildUser(online: false)));

        await notifier.refreshCurrentUser();

        expect(
          container.read(authNotifierProvider).user?.status.online,
          isFalse,
        );
        expect(container.read(userMenuStateProvider).isAway, isTrue);
      },
    );

    test('discards a refresh that completes after logout', () async {
      final (container, notifier, repo) = await _buildSession();

      when(() => _storage().deleteAccessToken()).thenAnswer((_) async {});
      final gate = Completer<Result<User>>();
      when(() => repo.getCurrentUser()).thenAnswer((_) => gate.future);
      final refresh = notifier.refreshCurrentUser();

      await notifier.logout();

      gate.complete(Success(_buildUser()));
      await refresh;

      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
    });
  });

  group('Server persistence ordering (SR2)', () {
    test(
      'a queued custom-status write cannot undo a confirmed presence change on the server',
      () async {
        final (container, notifier, repo) = await _buildSession();

        // Model the inspected backend contract: change-status persists
        // whatever online value the client sent, at response time.
        bool? statusSentOnline;
        bool? persistedOnline;
        final changeGate = Completer<Result<void>>();
        when(
          () => repo.changeStatus(
            icon: any(named: 'icon'),
            text: any(named: 'text'),
            pauseNotifications: any(named: 'pauseNotifications'),
            statusTimeout: any(named: 'statusTimeout'),
            clearStatus: any(named: 'clearStatus'),
            online: any(named: 'online'),
          ),
        ).thenAnswer((invocation) {
          statusSentOnline = invocation.namedArguments[#online] as bool;
          return changeGate.future;
        });
        when(() => repo.setPresence(online: any(named: 'online'))).thenAnswer((
          invocation,
        ) {
          persistedOnline = invocation.namedArguments[#online] as bool;
          return Future.value(const Success(null));
        });

        // The older custom-status request starts first and stays pending.
        final statusSave = notifier.changeStatus(
          icon: '',
          text: 'Commuting',
          timeout: StatusTimeout.thirtyMinutes,
          pauseNotifications: false,
        );
        await _flushAsync();
        expect(statusSentOnline, isTrue);

        // The presence toggle is requested second: it must not reach the
        // backend until the older write has resolved.
        final toggle = notifier.toggleOnlineStatus();
        await _flushAsync();
        verifyNever(() => repo.setPresence(online: any(named: 'online')));

        changeGate.complete(const Success(null));
        expect(await statusSave, isTrue);
        expect(await toggle, isA<PresenceConfirmed>());

        // Server received changeStatus(online=true) then
        // setPresence(online=false): the latest intent persisted.
        expect(statusSentOnline, isTrue);
        expect(persistedOnline, isFalse);
        // The local state agrees with the server.
        expect(
          container.read(authNotifierProvider).user?.status.online,
          isFalse,
        );
        expect(container.read(userMenuStateProvider).isAway, isTrue);
      },
    );

    test(
      'a custom-status save made after a confirmed toggle carries the new presence',
      () async {
        final (container, notifier, repo) = await _buildSession();

        bool? statusSentOnline;
        when(
          () => repo.changeStatus(
            icon: any(named: 'icon'),
            text: any(named: 'text'),
            pauseNotifications: any(named: 'pauseNotifications'),
            statusTimeout: any(named: 'statusTimeout'),
            clearStatus: any(named: 'clearStatus'),
            online: any(named: 'online'),
          ),
        ).thenAnswer((invocation) {
          statusSentOnline = invocation.namedArguments[#online] as bool;
          return Future.value(const Success(null));
        });
        _stubSetPresence(repo, Future.value(const Success(null)));

        expect(await notifier.toggleOnlineStatus(), isA<PresenceConfirmed>());
        final saved = await notifier.changeStatus(
          icon: '',
          text: 'Deep focus',
          timeout: StatusTimeout.oneHour,
          pauseNotifications: false,
        );

        expect(saved, isTrue);
        // The write carried the confirmed Away value, not the pre-toggle
        // Active value the dialog was opened with.
        expect(statusSentOnline, isFalse);
        final status = container.read(authNotifierProvider).user?.status;
        expect(status?.online, isFalse);
        expect(status?.text, 'Deep focus');
      },
    );

    test(
      'clearStatus after a confirmed toggle keeps the confirmed presence',
      () async {
        final (container, notifier, repo) = await _buildSession();

        _stubChangeStatus(repo, Future.value(const Success(null)));
        _stubSetPresence(repo, Future.value(const Success(null)));

        expect(await notifier.toggleOnlineStatus(), isA<PresenceConfirmed>());
        final cleared = await notifier.clearStatus();

        expect(cleared, isTrue);
        verify(
          () => repo.changeStatus(
            icon: '',
            text: '',
            pauseNotifications: false,
            statusTimeout: 'dont-clear',
            clearStatus: true,
            online: false,
          ),
        ).called(1);
        final status = container.read(authNotifierProvider).user?.status;
        expect(status?.text, isNull);
        expect(status?.emoji, isNull);
        expect(status?.online, isFalse);
      },
    );

    test(
      'a status write queued behind a pending toggle is dropped at logout',
      () async {
        final (container, notifier, repo) = await _buildSession();
        when(() => _storage().deleteAccessToken()).thenAnswer((_) async {});

        final presenceGate = Completer<Result<void>>();
        _stubSetPresence(repo, presenceGate.future);
        final toggle = notifier.toggleOnlineStatus();
        await _flushAsync();

        bool changeStatusSent = false;
        when(
          () => repo.changeStatus(
            icon: any(named: 'icon'),
            text: any(named: 'text'),
            pauseNotifications: any(named: 'pauseNotifications'),
            statusTimeout: any(named: 'statusTimeout'),
            clearStatus: any(named: 'clearStatus'),
            online: any(named: 'online'),
          ),
        ).thenAnswer((_) async {
          changeStatusSent = true;
          return Future.value(const Success(null));
        });

        // Queued behind the pending toggle — never sent before the logout.
        final statusSave = notifier.changeStatus(
          icon: '',
          text: 'Commuting',
          timeout: StatusTimeout.thirtyMinutes,
          pauseNotifications: false,
        );
        await _flushAsync();
        expect(changeStatusSent, isFalse);

        await notifier.logout();

        presenceGate.complete(const Success(null));
        expect(await toggle, isA<PresenceSkipped>());
        expect(await statusSave, isFalse);
        expect(changeStatusSent, isFalse);
      },
    );
  });

  group('Issue #127 concurrency defect regressions (FC1–FC3)', () {
    test(
      'FC1: old organisation completion must not poison next toggle',
      () async {
        final (container, notifier, repo) = await _buildSession();
        final gate = Completer<Result<void>>();
        final sent = <bool>[];
        when(() => repo.setPresence(online: any(named: 'online'))).thenAnswer((
          inv,
        ) {
          sent.add(inv.namedArguments[#online] as bool);
          return sent.length == 1
              ? gate.future
              : Future.value(const Success(null));
        });
        final old = notifier.toggleOnlineStatus();
        await _flushAsync();
        when(() => repo.getCurrentUser()).thenAnswer(
          (_) async => Success(_buildUser(org: 'org-2', online: true)),
        );
        await notifier.refreshCurrentUser();
        expect(container.read(authNotifierProvider).user!.currentOrg, 'org-2');
        gate.complete(const Success(null));
        expect(await old, isA<PresenceSkipped>());
        expect(await notifier.toggleOnlineStatus(), isA<PresenceConfirmed>());
        expect(
          sent,
          [false, false],
          reason:
              'A discarded org-1 confirmation cannot seed the org-2 presence cache',
        );
      },
    );

    test(
      'FC2: old session pending mutation must not suppress fresh server presence',
      () async {
        final (container, notifier, repo) = await _buildSession();
        final gate = Completer<Result<void>>();
        _stubSetPresence(repo, gate.future);
        final old = notifier.toggleOnlineStatus();
        await _flushAsync();
        when(() => _storage().deleteAccessToken()).thenAnswer((_) async {});
        when(() => _storage().saveAccessToken(any())).thenAnswer((_) async {});
        _stubLogin(repo, _buildUser(id: 'user-2', online: true));
        await notifier.logout();
        await notifier.login(email: 'new@example.com', password: 'Password123');
        when(() => repo.getCurrentUser()).thenAnswer(
          (_) async => Success(_buildUser(id: 'user-2', online: false)),
        );
        await notifier.refreshCurrentUser();
        final adopted = container
            .read(authNotifierProvider)
            .user!
            .status
            .online;
        gate.complete(const Success(null));
        expect(await old, isA<PresenceSkipped>());
        expect(
          adopted,
          isFalse,
          reason:
              'A mutation in the previous session must not make this refresh overlapping',
        );
      },
    );

    test(
      'FC2: old session mutation completing after new session mutation does not corrupt counter',
      () async {
        final (container, notifier, repo) = await _buildSession();
        final oldGate = Completer<Result<void>>();
        _stubSetPresence(repo, oldGate.future);
        final old = notifier.toggleOnlineStatus();
        await _flushAsync();

        when(() => _storage().deleteAccessToken()).thenAnswer((_) async {});
        when(() => _storage().saveAccessToken(any())).thenAnswer((_) async {});
        _stubLogin(repo, _buildUser(id: 'user-2', online: true));
        await notifier.logout();
        await notifier.login(email: 'new@example.com', password: 'Password123');

        // Start and complete a mutation in session 2
        _stubChangeStatus(repo, Future.value(const Success(null)));
        expect(
          await notifier.changeStatus(
            icon: '🚀',
            text: 'Session 2',
            timeout: StatusTimeout.oneHour,
            pauseNotifications: false,
          ),
          isTrue,
        );

        // Complete old request from session 1 after session 2 mutation
        oldGate.complete(const Success(null));
        expect(await old, isA<PresenceSkipped>());

        // Subsequent refresh in session 2 adopts fresh server presence without being blocked
        when(() => repo.getCurrentUser()).thenAnswer(
          (_) async => Success(_buildUser(id: 'user-2', online: false)),
        );
        await notifier.refreshCurrentUser();
        expect(
          container.read(authNotifierProvider).user!.status.online,
          isFalse,
        );
      },
    );

    test(
      'FC3: successful queued status must survive a later failed status write',
      () async {
        final (container, notifier, repo) = await _buildSession();
        final a = Completer<Result<void>>();
        final b = Completer<Result<void>>();
        final replies = [a.future, b.future];
        when(
          () => repo.changeStatus(
            icon: any(named: 'icon'),
            text: any(named: 'text'),
            pauseNotifications: any(named: 'pauseNotifications'),
            statusTimeout: any(named: 'statusTimeout'),
            clearStatus: any(named: 'clearStatus'),
            online: any(named: 'online'),
          ),
        ).thenAnswer((_) => replies.removeAt(0));

        final first = notifier.changeStatus(
          icon: '',
          text: 'First',
          timeout: StatusTimeout.oneHour,
          pauseNotifications: false,
        );
        await _flushAsync();
        final second = notifier.changeStatus(
          icon: '',
          text: 'Second',
          timeout: StatusTimeout.oneHour,
          pauseNotifications: false,
        );
        a.complete(const Success(null));
        expect(await first, isTrue);
        b.complete(
          const Failure<void>(
            ApiFailure(
              message: 'Rejected',
              kind: ApiFailureKind.client,
              statusCode: 400,
            ),
          ),
        );
        expect(await second, isFalse);
        expect(
          container.read(authNotifierProvider).user!.status.text,
          'First',
          reason:
              'First persisted successfully and Second failed without replacing it',
        );
      },
    );

    test(
      'FC3: successful clearStatus survives a later failed changeStatus',
      () async {
        final (container, notifier, repo) = await _buildSession(
          seedUser: _buildUser(online: true),
        );
        // Give user initial custom status
        _stubChangeStatus(repo, Future.value(const Success(null)));
        await notifier.changeStatus(
          icon: '💬',
          text: 'Initial',
          timeout: StatusTimeout.oneHour,
          pauseNotifications: false,
        );
        expect(
          container.read(authNotifierProvider).user!.status.text,
          'Initial',
        );

        final a = Completer<Result<void>>();
        final b = Completer<Result<void>>();
        final replies = [a.future, b.future];
        when(
          () => repo.changeStatus(
            icon: any(named: 'icon'),
            text: any(named: 'text'),
            pauseNotifications: any(named: 'pauseNotifications'),
            statusTimeout: any(named: 'statusTimeout'),
            clearStatus: any(named: 'clearStatus'),
            online: any(named: 'online'),
          ),
        ).thenAnswer((_) => replies.removeAt(0));

        final clear = notifier.clearStatus();
        await _flushAsync();
        final change = notifier.changeStatus(
          icon: '🚀',
          text: 'NewStatus',
          timeout: StatusTimeout.oneHour,
          pauseNotifications: false,
        );

        a.complete(const Success(null));
        expect(await clear, isTrue);

        b.complete(
          const Failure<void>(
            ApiFailure(
              message: 'Failed to save',
              kind: ApiFailureKind.client,
              statusCode: 500,
            ),
          ),
        );
        expect(await change, isFalse);

        final status = container.read(authNotifierProvider).user!.status;
        expect(
          status.text,
          isNull,
          reason:
              'Cleared status was confirmed and survives subsequent failure',
        );
        expect(status.emoji, isNull);
      },
    );
  });

  group('UserModel.toEntity presence hydration', () {
    test('carries the parsed online flag into User.status', () {
      expect(_modelUser(online: false).toEntity().status.online, isFalse);
      expect(_modelUser(online: true).toEntity().status.online, isTrue);
    });
  });

  group('StatusTimeout API contract', () {
    // Accepted values of zedu-be Profile.ParseStatusExpiry (services/profile
    // re-parses `status_timeout` and returns 400 for unknown values).
    const backendAccepted = {
      '',
      '30 seconds',
      '30 second',
      '30 minutes',
      '30 minute',
      '1 hour',
      '1 hr',
      'today',
      'this week',
      'dont-clear',
      "don't-clear",
      'dont clear',
      "don't clear",
    };

    test('every StatusTimeout.apiValue is accepted by the backend', () {
      for (final timeout in StatusTimeout.values) {
        expect(
          backendAccepted.contains(timeout.apiValue),
          isTrue,
          reason:
              'StatusTimeout.${timeout.name} sends "${timeout.apiValue}", '
              'which the backend rejects with "invalid expiry value".',
        );
      }
    });

    test('dontRemove no longer sends the removed "don\'t remove" value', () {
      expect(StatusTimeout.dontRemove.apiValue, 'dont-clear');
    });
  });

  group('AuthNotifier.refreshCurrentUser keeps the organisation plan', () {
    User paidUser({String org = 'org-1'}) => User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '+1234567890',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026, 1, 1),
      currentOrg: org,
      currentOrganisationSlug: 'slug-$org',
      avatarUrl: '',
      defaultAvatarUrl: '',
      creditBalance: 120,
      subscriptionPlanId: 'pro',
      aiCreditsPurchasable: false,
      status: const UserStatus(online: true),
    );

    test('a same-organisation refresh keeps the balance and plan', () async {
      final (container, notifier, repo) = await _buildSession(
        seedUser: paidUser(),
      );
      expect(container.read(authNotifierProvider).user?.creditBalance, 120);

      // The profile endpoint has no organisation block: 0 and 'free'.
      when(
        () => repo.getCurrentUser(),
      ).thenAnswer((_) async => Success(_buildUser(firstName: 'Renamed')));
      await notifier.refreshCurrentUser();

      final user = container.read(authNotifierProvider).user!;
      expect(user.firstName, 'Renamed');
      expect(user.creditBalance, 120);
      expect(user.subscriptionPlanId, 'pro');
      expect(user.aiCreditsPurchasable, isFalse);
    });

    test('a refresh into another organisation takes its values', () async {
      final (container, notifier, repo) = await _buildSession(
        seedUser: paidUser(),
      );

      when(
        () => repo.getCurrentUser(),
      ).thenAnswer((_) async => Success(_buildUser(org: 'org-2')));
      await notifier.refreshCurrentUser();

      final user = container.read(authNotifierProvider).user!;
      expect(user.currentOrg, 'org-2');
      expect(user.creditBalance, 0);
      expect(user.subscriptionPlanId, 'free');
    });
  });
}
