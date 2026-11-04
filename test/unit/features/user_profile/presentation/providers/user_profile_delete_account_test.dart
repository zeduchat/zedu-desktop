import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockUserProfileRepository extends Mock
    implements UserProfileRepository {}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Test Workspace', avatar: ''),
  );
}

/// Records the logout call the notifier is expected to make once the server
/// confirms the account is gone, and flips the session to unauthenticated.
class _FakeAuthNotifier extends AuthNotifier {
  int logoutCalls = 0;

  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

void main() {
  group('UserProfileNotifier.deleteAccount', () {
    late _MockUserProfileRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = _MockUserProfileRepository();
      container = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);
    });

    test('signs the user out once the account is deleted', () async {
      when(() => repository.deleteAccount()).thenAnswer(
        (_) async => const Success<void>(null),
      );

      final notifier = container.read(userProfileNotifierProvider.notifier);
      await notifier.deleteAccount();

      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(
        (container.read(authNotifierProvider.notifier) as _FakeAuthNotifier)
            .logoutCalls,
        1,
      );
      expect(notifier.state.successMessage, isNotNull);
    });

    test('keeps the session when the delete fails', () async {
      when(() => repository.deleteAccount()).thenAnswer(
        (_) async => const Failure<void>(
          ApiFailure(message: 'Could not delete the account.'),
        ),
      );

      final notifier = container.read(userProfileNotifierProvider.notifier);
      await notifier.deleteAccount();

      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.authenticated,
      );
      expect(
        (container.read(authNotifierProvider.notifier) as _FakeAuthNotifier)
            .logoutCalls,
        0,
      );
    });
  });
}
