import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockAuthInterceptor extends Mock implements AuthInterceptor {}

User _userWithStatus(UserStatus status) => User(
  id: 'user-1',
  firstName: 'Test',
  lastName: 'User',
  email: 'test@example.com',
  phone: '+1234567890',
  username: 'testuser',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026, 1, 1),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'slug-org-1',
  avatarUrl: '',
  defaultAvatarUrl: '',
  status: status,
);

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// Restores a signed-in session for a user with [status].
Future<ProviderContainer> _sessionWith(UserStatus status) async {
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
  ).thenAnswer((_) async => Success(_userWithStatus(const UserStatus())));

  final notifier = container.read(authNotifierProvider.notifier);
  await _flushAsync();
  expect(container.read(authNotifierProvider).status, AuthStatus.authenticated);
  // Then the status arrives, as it does after a change or a server refresh.
  _setStatus(notifier, status);
  return container;
}

void _setStatus(AuthNotifier notifier, UserStatus status) {
  notifier.state = notifier.state.copyWith(user: _userWithStatus(status));
}

UserStatus? _status(ProviderContainer c) =>
    c.read(authNotifierProvider).user?.status;

void main() {
  group('AuthNotifier custom status "Clear after"', () {
    test('clears the status once its time passes, keeping presence', () async {
      final container = await _sessionWith(
        UserStatus(
          emoji: '📅',
          text: 'In a meeting',
          // Long enough to outlast the session setup above.
          expiresAt: DateTime.now().add(const Duration(milliseconds: 600)),
          pauseNotifications: true,
        ),
      );
      expect(_status(container)!.hasCustomStatus, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 900));

      final status = _status(container)!;
      expect(status.hasCustomStatus, isFalse);
      expect(status.text, isNull);
      expect(status.emoji, isNull);
      expect(status.expiresAt, isNull);
      expect(status.pauseNotifications, isFalse);
      expect(
        status.online,
        isTrue,
        reason: 'presence is not part of the status',
      );
    });

    test('clears a status that had already expired when loaded', () async {
      final container = await _sessionWith(
        UserStatus(
          text: 'Commuting',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );
      await _flushAsync();

      expect(_status(container)!.text, isNull);
    });

    test('keeps a status with no expiry', () async {
      final container = await _sessionWith(
        const UserStatus(emoji: '🌴', text: 'Vacationing'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(_status(container)!.text, 'Vacationing');
      expect(_status(container)!.hasCustomStatus, isTrue);
    });

    test('a later expiry set before the timer fires wins', () async {
      final container = await _sessionWith(
        UserStatus(
          text: 'In a meeting',
          expiresAt: DateTime.now().add(const Duration(milliseconds: 80)),
        ),
      );
      // Extend it (as a new status from the server would) before it runs out.
      _setStatus(
        container.read(authNotifierProvider.notifier),
        UserStatus(
          text: 'In a meeting',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(_status(container)!.text, 'In a meeting');
    });
  });
}
