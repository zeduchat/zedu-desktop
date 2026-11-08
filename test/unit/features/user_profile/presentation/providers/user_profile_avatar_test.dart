import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockRepo extends Mock implements UserProfileRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

class _Workspaces extends WorkspaceNotifier {
  @override
  WorkspaceState build() => WorkspaceState(
    selectedWorkspace: Workspace(id: 'A', name: 'WS A', avatar: ''),
  );
}

const _withPhoto = ProfileAccount(
  name: 'Ada',
  email: 'ada@zedu.chat',
  timezone: 'Africa/Lagos',
  avatarUrl: 'https://cdn.zedu.chat/ada.png',
);

const _withoutPhoto = ProfileAccount(
  name: 'Ada',
  email: 'ada@zedu.chat',
  timezone: 'Africa/Lagos',
);

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
    when(
      () => repo.getNotificationPreferences(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(
      () => repo.getSecuritySessions(userId: any(named: 'userId')),
    ).thenAnswer((_) => failed());
    when(
      () => repo.getOrganization(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(
      () => repo.getTeamMembers(orgId: any(named: 'orgId')),
    ).thenAnswer((_) => failed());
    when(() => repo.getRolesAndPermissions()).thenAnswer((_) => failed());
    when(() => repo.getBillingInfo()).thenAnswer((_) => failed());
  });

  tearDown(() async => locator.reset());

  Future<ProviderContainer> container() async {
    final c = ProviderContainer(
      overrides: [
        userProfileRepositoryProvider.overrideWithValue(repo),
        workspaceProvider.overrideWith(_Workspaces.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(userProfileNotifierProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  test('uploading a photo sends the file and reloads the account', () async {
    final c = await container();
    when(
      () => repo.uploadAvatar(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.getAccount(),
    ).thenAnswer((_) async => const Success(_withPhoto));

    await c
        .read(userProfileNotifierProvider.notifier)
        .uploadAvatar('C:/pics/ada.png');

    verify(() => repo.uploadAvatar('C:/pics/ada.png')).called(1);
    final state = c.read(userProfileNotifierProvider);
    expect(state.error, isNull);
    expect(state.isSaving, isFalse);
    expect(state.account?.avatarUrl, _withPhoto.avatarUrl);
  });

  test('removing the photo reloads the account without one', () async {
    final c = await container();
    when(
      () => repo.removeAvatar(),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.getAccount(),
    ).thenAnswer((_) async => const Success(_withoutPhoto));

    await c.read(userProfileNotifierProvider.notifier).removeAvatar();

    verify(() => repo.removeAvatar()).called(1);
    final state = c.read(userProfileNotifierProvider);
    expect(state.error, isNull);
    expect(state.account?.avatarUrl, isNull);
  });

  test('a failed upload reports the error and stops saving', () async {
    final c = await container();
    when(() => repo.uploadAvatar(any())).thenAnswer(
      (_) async => Failure<void>(const ApiFailure(message: 'too large')),
    );

    await c
        .read(userProfileNotifierProvider.notifier)
        .uploadAvatar('C:/pics/huge.png');

    final state = c.read(userProfileNotifierProvider);
    expect(state.error, isNotNull);
    expect(state.isSaving, isFalse);
  });
}
