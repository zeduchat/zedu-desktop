import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockAuthInterceptor extends Mock implements AuthInterceptor {}

User _user(String id) => User(
  id: id,
  firstName: 'Test',
  lastName: 'User',
  email: '$id@example.com',
  phone: '',
  username: id,
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'org',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

/// A storage mock backed by a map, as the app's secure storage would be.
MockSecureStorageService _storageOver(Map<String, String> disk) {
  final storage = MockSecureStorageService();
  when(() => storage.readAll()).thenAnswer((_) async => Map.of(disk));
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
  when(
    () => storage.getAccessToken(),
  ).thenAnswer((_) async => disk['access_token']);
  when(() => storage.deleteAccessToken()).thenAnswer((_) async {
    disk.remove('access_token');
  });
  return storage;
}

void main() {
  group('DmDraftStore.deleteAllForUser', () {
    test("removes every draft of that user and nobody else's", () async {
      final disk = <String, String>{
        'dm_draft_u1_org-1_ch-a': '{"text":"secret a","updatedAt":1}',
        'dm_draft_u1_org-2_ch-b': '{"text":"secret b","updatedAt":2}',
        'dm_draft_u10_org-1_ch-c': '{"text":"other user","updatedAt":3}',
        'dm_draft_u2_org-1_ch-a': '{"text":"other user","updatedAt":4}',
        'access_token': 'token',
      };

      await DmDraftStore.deleteAllForUser(_storageOver(disk), 'u1');

      expect(disk.keys, {
        'dm_draft_u10_org-1_ch-c',
        'dm_draft_u2_org-1_ch-a',
        'access_token',
      });
    });

    test('drafts saved through the store are found and removed', () async {
      final disk = <String, String>{};
      final storage = _storageOver(disk);
      final store = DmDraftStore(storage, userId: 'u1', orgId: 'org-1');
      await store.save('ch-a', 'half-written message');
      expect(disk.keys, hasLength(1));

      await DmDraftStore.deleteAllForUser(storage, 'u1');

      expect(disk, isEmpty);
    });
  });

  group('AuthNotifier.logout', () {
    tearDown(() => locator.reset());

    test("signing out deletes the user's saved drafts", () async {
      final disk = <String, String>{
        'access_token': 'token',
        'dm_draft_u1_org-1_ch-a': '{"text":"secret","updatedAt":1}',
        'dm_draft_u2_org-1_ch-a': '{"text":"other user","updatedAt":2}',
      };
      final repo = MockAuthRepository();
      locator.registerSingleton<SecureStorageService>(_storageOver(disk));
      locator.registerSingleton<AuthInterceptor>(MockAuthInterceptor());
      when(
        () => repo.getCurrentUser(),
      ).thenAnswer((_) async => Success(_user('u1')));
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await pumpEventQueue();
      expect(container.read(authNotifierProvider).user?.id, 'u1');

      await notifier.logout();

      expect(disk.containsKey('dm_draft_u1_org-1_ch-a'), isFalse);
      expect(disk.containsKey('access_token'), isFalse);
      expect(disk.containsKey('dm_draft_u2_org-1_ch-a'), isTrue);
      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.unauthenticated,
      );
    });
  });
}
