import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _FakeDmRepository extends Fake implements DmRepository {
  final List<({String orgId, int page, String? search})> calls = [];
  List<DmConversation> Function(String orgId, int page, String? search)?
  handler;

  /// How many result pages the server reports for every search.
  int totalPages = 1;

  @override
  Future<DmConversationsPage> getConversations({
    required String orgId,
    int page = 1,
    bool recentDm = false,
    String? search,
  }) async {
    calls.add((orgId: orgId, page: page, search: search));
    final list = handler != null
        ? handler!(orgId, page, search)
        : <DmConversation>[];
    return DmConversationsPage(
      conversations: list,
      currentPage: page,
      totalPages: totalPages,
    );
  }
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Org 1', avatar: ''),
  );
}

DmConversation _conversation(String channelId, String username) {
  return DmConversation(
    channelId: channelId,
    username: username,
    participantId: 'user-$channelId',
    previewMessage: '',
    unreadCount: 0,
  );
}

void main() {
  group('DmSearchResultsNotifier', () {
    late ProviderContainer container;
    late _FakeDmRepository repo;

    setUp(() {
      repo = _FakeDmRepository();
      container = ProviderContainer(
        overrides: [
          workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
          dmRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() => container.dispose());

    test(
      'returns empty without calling repository for whitespace query',
      () async {
        final results = await container.read(
          dmSearchResultsProvider('   ').future,
        );
        expect(results, isEmpty);
        expect(repo.calls, isEmpty);
      },
    );

    test('calls repository with trimmed search query and page 1', () async {
      repo.handler = (orgId, page, search) => [
        _conversation('c1', 'Ada Lovelace'),
      ];

      final results = await container.read(
        dmSearchResultsProvider('  ada  ').future,
      );

      expect(results.length, 1);
      expect(results.first.displayName, 'Ada Lovelace');
      expect(repo.calls.length, 1);
      expect(repo.calls.first.orgId, 'org-1');
      expect(repo.calls.first.page, 1);
      expect(repo.calls.first.search, 'ada');
    });

    test(
      'loadMore fetches next page with search query and appends results',
      () async {
        repo.totalPages = 2;
        repo.handler = (orgId, page, search) {
          if (page == 1) {
            return List.generate(
              DmRepository.pageSize,
              (i) => _conversation('c-$i', 'Ada $i'),
            );
          }
          return [_conversation('c-extra', 'Ada Extra')];
        };

        final provider = dmSearchResultsProvider('ada');
        final initial = await container.read(provider.future);
        expect(initial.length, DmRepository.pageSize);
        expect(container.read(provider.notifier).hasMore, isTrue);

        await container.read(provider.notifier).loadMore();

        final updated = container.read(provider).value ?? [];
        expect(updated.length, DmRepository.pageSize + 1);
        expect(updated.last.displayName, 'Ada Extra');
        expect(repo.calls.length, 2);
        expect(repo.calls[1].page, 2);
        expect(repo.calls[1].search, 'ada');
        expect(container.read(provider.notifier).hasMore, isFalse);
      },
    );

    test('refresh reloads page 1 with search query', () async {
      var callCount = 0;
      repo.handler = (orgId, page, search) {
        callCount++;
        return [_conversation('c-$callCount', 'Ada $callCount')];
      };

      final provider = dmSearchResultsProvider('ada');
      final first = await container.read(provider.future);
      expect(first.first.displayName, 'Ada 1');

      await container.read(provider.notifier).refresh();

      final refreshed = container.read(provider).value ?? [];
      expect(refreshed.first.displayName, 'Ada 2');
    });
  });
}
