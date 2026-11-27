import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockApi extends Mock implements ApiBaseService {}

class _MockStorage extends Mock implements SecureStorageService {}

class _MockRepo extends Mock implements NotificationCenterRepository {}

class _FakeAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'u1',
      firstName: 'Ada',
      lastName: 'Obi',
      email: 'ada@zedu.test',
      phone: '',
      username: 'ada',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime.utc(2026, 11, 27),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'zedu',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

class _FakeWorkspace extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Zedu', avatar: ''),
  );
}

AppNotification _n(String id, {String message = 'm'}) => AppNotification(
  id: id,
  title: 't$id',
  message: message,
  sentAt: DateTime(2026, 11, 27, 12),
);

void main() {
  group('mergeFirstPage (Ziki #33700 review)', () {
    test('new items go on top, changed ones are updated, later pages stay', () {
      final loaded = [_n('3'), _n('2'), _n('1'), _n('old')];
      final firstPage = [_n('4'), _n('3', message: 'edited'), _n('2')];

      final merged = mergeFirstPage(firstPage, loaded);

      expect(merged.map((i) => i.id), ['4', '3', '2', '1', 'old']);
      expect(merged[1].message, 'edited');
    });
  });

  group('NotificationCenterRepository.markRead', () {
    test('marks the notification read on the server', () async {
      final api = _MockApi();
      when(
        () => api.put<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: <String, dynamic>{},
        ),
      );
      final repository = NotificationCenterRepository(
        api: api,
        storage: _MockStorage(),
      );

      await repository.markRead('n7');

      verify(
        () => api.put<Map<String, dynamic>>(
          path: '/users/onesignal-notifications/n7/read',
        ),
      ).called(1);
    });
  });

  group('NotificationCenterNotifier (Ziki #33700 review)', () {
    late _MockRepo repo;
    late ProviderContainer container;

    setUp(() {
      locator.registerSingleton<ApiBaseService>(_MockApi());
      locator.registerSingleton<SecureStorageService>(_MockStorage());
      repo = _MockRepo();
      when(() => repo.readIds(any(), any())).thenAnswer((_) async => {});
      when(
        () => repo.seenAt(any(), any()),
      ).thenAnswer((_) async => DateTime(2026, 11, 27, 9));
      when(
        () => repo.saveReadIds(any(), any(), any()),
      ).thenAnswer((_) async {});
      when(() => repo.markRead(any())).thenAnswer((_) async {});
      when(
        () => repo.load('org-1'),
      ).thenAnswer((_) async => (items: [_n('2'), _n('1')], hasMore: true));
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuth.new),
          workspaceProvider.overrideWith(_FakeWorkspace.new),
          notificationCenterRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await locator.reset();
    });

    Future<NotificationCenterNotifier> loaded() async {
      container.listen(notificationCenterProvider, (_, _) {});
      final notifier = container.read(notificationCenterProvider.notifier);
      await notifier.refresh();
      return notifier;
    }

    test(
      'opening an unread notification marks it read on the server',
      () async {
        final notifier = await loaded();

        await notifier.select(_n('2'));

        verify(() => repo.markRead('2')).called(1);
        final state = container.read(notificationCenterProvider);
        expect(state.isUnread(_n('2')), isFalse);
      },
    );

    test('a failed server call still marks it read here', () async {
      when(
        () => repo.markRead(any()),
      ).thenThrow(const ApiFailure(message: 'x'));
      final notifier = await loaded();

      await notifier.select(_n('2'));

      expect(
        container.read(notificationCenterProvider).isUnread(_n('2')),
        isFalse,
      );
    });

    test('a failed page shows an error and can be retried', () async {
      when(
        () => repo.load('org-1', page: 2),
      ).thenThrow(const ApiFailure(message: 'Server unavailable'));
      final notifier = await loaded();

      await notifier.loadMore();
      var state = container.read(notificationCenterProvider);
      expect(state.loadMoreError, isNotNull);
      expect(state.hasMore, isTrue);

      when(
        () => repo.load('org-1', page: 2),
      ).thenAnswer((_) async => (items: [_n('0')], hasMore: false));
      await notifier.loadMore();
      state = container.read(notificationCenterProvider);
      expect(state.loadMoreError, isNull);
      expect(state.items.map((i) => i.id), ['2', '1', '0']);
    });

    test('refresh keeps later pages and the selection', () async {
      when(
        () => repo.load('org-1', page: 2),
      ).thenAnswer((_) async => (items: [_n('0')], hasMore: true));
      final notifier = await loaded();
      await notifier.loadMore();
      await notifier.select(_n('0'));
      when(() => repo.load('org-1')).thenAnswer(
        (_) async => (items: [_n('3'), _n('2'), _n('1')], hasMore: true),
      );

      await notifier.refresh();

      final state = container.read(notificationCenterProvider);
      expect(state.items.map((i) => i.id), ['3', '2', '1', '0']);
      expect(state.selectedId, '0');
      expect(state.page, 2);
    });
  });
}
