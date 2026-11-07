import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class DmSidebarList extends ConsumerStatefulWidget {
  const DmSidebarList({super.key});

  @override
  ConsumerState<DmSidebarList> createState() => _DmSidebarListState();
}

class _DmSidebarListState extends ConsumerState<DmSidebarList> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _debouncedQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _debouncedQuery = '';
      });
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _debouncedQuery = trimmed;
        });
      }
    });
    setState(() {});
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    setState(() {
      _debouncedQuery = value.trim();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _debouncedQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textColor = colors.onPrimary.withValues(alpha: 0.9);

    return Container(
      color: colors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSwitcherHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: colors.onPrimary.withValues(alpha: 0.68),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Icon(Icons.search, color: textColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onChanged,
                            onSubmitted: _onSubmitted,
                            cursorColor: textColor,
                            style: TextStyle(color: textColor, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Find a Conversation',
                              hintStyle: TextStyle(
                                color: textColor,
                                fontSize: 12,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                            icon: Icon(Icons.close, color: textColor, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                          )
                        else
                          const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                (_debouncedQuery.isEmpty
                        ? ref.watch(dmListProvider)
                        : ref.watch(dmSearchResultsProvider(_debouncedQuery)))
                    .when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      error: (err, stack) => Center(
                        child: Text(
                          'Failed to load DMs',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                      data: (conversations) {
                        final actions = ref.watch(
                          dmConversationActionsProvider,
                        );
                        final currentUserId = ref
                            .watch(authNotifierProvider)
                            .user
                            ?.id;
                        final allConversations = [...conversations];
                        if (_debouncedQuery.isNotEmpty &&
                            currentUserId != null &&
                            currentUserId.isNotEmpty &&
                            ('you'.contains(_debouncedQuery.toLowerCase()) ||
                                '(you)'.contains(
                                  _debouncedQuery.toLowerCase(),
                                ))) {
                          final cachedList =
                              ref.watch(dmListProvider).value ?? [];
                          for (final c in cachedList) {
                            if (c.participantId == currentUserId &&
                                !allConversations.any(
                                  (x) => x.channelId == c.channelId,
                                )) {
                              allConversations.add(c);
                            }
                          }
                        }
                        final visibleConversations =
                            allConversations
                                .where(
                                  (conversation) => !actions.deletedIds
                                      .contains(conversation.channelId),
                                )
                                .toList()
                              ..sort((a, b) {
                                final aSelf =
                                    currentUserId != null &&
                                    currentUserId.isNotEmpty &&
                                    a.participantId == currentUserId;
                                final bSelf =
                                    currentUserId != null &&
                                    currentUserId.isNotEmpty &&
                                    b.participantId == currentUserId;
                                if (aSelf != bSelf) return aSelf ? -1 : 1;

                                final aPinned = actions.pinnedIds.contains(
                                  a.channelId,
                                );
                                final bPinned = actions.pinnedIds.contains(
                                  b.channelId,
                                );
                                if (aPinned != bPinned) return aPinned ? -1 : 1;
                                return b.lastActivityAt.compareTo(
                                  a.lastActivityAt,
                                );
                              });
                        if (visibleConversations.isEmpty) {
                          return Center(
                            child: Text(
                              _debouncedQuery.isEmpty
                                  ? 'No recent chats'
                                  : 'No conversations match',
                              style: TextStyle(
                                color: colors.onPrimary.withValues(alpha: 0.5),
                              ),
                            ),
                          );
                        }
                        return NotificationListener<ScrollNotification>(
                          onNotification: (scrollInfo) {
                            if (scrollInfo is ScrollEndNotification &&
                                scrollInfo.metrics.pixels >=
                                    scrollInfo.metrics.maxScrollExtent * 0.85) {
                              if (_debouncedQuery.isEmpty) {
                                final notifier = ref.read(
                                  dmListProvider.notifier,
                                );
                                if (notifier.hasMore) {
                                  notifier.loadMore();
                                }
                              } else {
                                final notifier = ref.read(
                                  dmSearchResultsProvider(
                                    _debouncedQuery,
                                  ).notifier,
                                );
                                if (notifier.hasMore) {
                                  notifier.loadMore();
                                }
                              }
                            }
                            return false;
                          },
                          // Transparent Material so each row's hover and
                          // selected ink paints above the sidebar colour.
                          child: Material(
                            type: MaterialType.transparency,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: visibleConversations.length,
                              itemBuilder: (context, index) {
                                return DmListTile(
                                  conversation: visibleConversations[index],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
