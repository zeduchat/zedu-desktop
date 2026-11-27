import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

/// A signed-in user, without the real session restore.
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.userId);
  final String userId;

  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: userId,
      firstName: 'Test',
      lastName: 'User',
      email: '$userId@example.com',
      phone: '',
      username: userId,
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'org',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

void main() {
  // What the app keeps on disk between launches.
  late Map<String, String> disk;

  setUp(() {
    disk = {};
    final storage = MockSecureStorageService();
    when(
      () => storage.readData(any()),
    ).thenAnswer((i) async => disk[i.positionalArguments.first as String]);
    when(() => storage.writeData(any(), any())).thenAnswer((i) async {
      disk[i.positionalArguments[0] as String] =
          i.positionalArguments[1] as String;
    });
    when(() => storage.deleteValue(any())).thenAnswer((i) async {
      disk.remove(i.positionalArguments.first as String);
    });
    locator.registerSingleton<SecureStorageService>(storage);
  });

  tearDown(() => locator.reset());

  /// One app launch for [userId].
  ProviderContainer launch(String userId) {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(userId)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle() => pumpEventQueue();

  final dndKey = DmPreferencesStore.dndKey('u1');

  test('Do Not Disturb is still on after a restart', () async {
    final first = launch('u1');
    first
        .read(notificationSettingsProvider.notifier)
        .setDndMode(const Duration(hours: 1));
    final until = first.read(notificationSettingsProvider).dndUntil!;
    await settle();
    first.dispose();

    final second = launch('u1');
    second.read(notificationSettingsProvider);
    await settle();

    final restored = second.read(notificationSettingsProvider);
    expect(restored.isDndActive, isTrue);
    expect(restored.dndUntil, until);
  });

  test('a restored pause still ends by itself', () async {
    disk[dndKey] = DateTime.now()
        .add(const Duration(milliseconds: 150))
        .toUtc()
        .toIso8601String();

    final container = launch('u1');
    container.read(notificationSettingsProvider);
    await settle();
    expect(container.read(notificationSettingsProvider).isDndActive, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await settle();

    expect(container.read(notificationSettingsProvider).dndUntil, isNull);
    expect(disk.containsKey(dndKey), isFalse);
  });

  test('a pause that ran out while the app was closed is ignored', () async {
    disk[dndKey] = DateTime.now()
        .subtract(const Duration(minutes: 5))
        .toUtc()
        .toIso8601String();

    final container = launch('u1');
    container.read(notificationSettingsProvider);
    await settle();

    expect(container.read(notificationSettingsProvider).dndUntil, isNull);
    expect(disk.containsKey(dndKey), isFalse);
  });

  test('turning Do Not Disturb off sticks after a restart', () async {
    final first = launch('u1');
    final settings = first.read(notificationSettingsProvider.notifier);
    settings.setDndMode(const Duration(hours: 1));
    settings.clearDndMode();
    await settle();
    first.dispose();

    final second = launch('u1');
    second.read(notificationSettingsProvider);
    await settle();

    expect(second.read(notificationSettingsProvider).isDndActive, isFalse);
  });

  test("another account on the same computer doesn't get it", () async {
    final first = launch('u1');
    first
        .read(notificationSettingsProvider.notifier)
        .setDndMode(const Duration(hours: 1));
    await settle();
    first.dispose();

    final other = launch('u2');
    other.read(notificationSettingsProvider);
    await settle();

    expect(other.read(notificationSettingsProvider).isDndActive, isFalse);
  });
}
