import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class LaterView extends ConsumerWidget {
  const LaterView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Row(
        children: [
          AppSidebarRail(
            activeType: null,
            laterSelected: true,
            onTypeSelected: (type) {
              ref.read(homeSidebarProvider.notifier).setType(type);
              context.go(AppRouter.home);
            },
          ),
          const Expanded(child: LaterBody()),
        ],
      ),
    ),
  );
}

class LaterBody extends ConsumerStatefulWidget {
  const LaterBody({super.key});
  @override
  ConsumerState<LaterBody> createState() => _LaterBodyState();
}

class _LaterBodyState extends ConsumerState<LaterBody> {
  final _pending = <String>{};
  Future<void> _remove(SavedMessage item) async {
    final org = ref.read(workspaceProvider).selectedWorkspace?.id;
    if (org == null || !_pending.add(item.id)) return;
    setState(() {});
    try {
      await ref.read(laterRepositoryProvider).remove(org, item.id);
      if (mounted && ref.read(workspaceProvider).selectedWorkspace?.id == org) {
        ref.invalidate(savedMessagesProvider);
      }
    } catch (_) {
      if (mounted && ref.read(workspaceProvider).selectedWorkspace?.id == org) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove saved message. Retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pending.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Text('Later', style: context.textTheme.headlineSmall),
            ),
            IconButton(
              tooltip: 'Refresh saved messages',
              onPressed: () => ref.invalidate(savedMessagesProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      Expanded(
        child: ref
            .watch(savedMessagesProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load saved messages.'),
                    TextButton(
                      onPressed: () => ref.invalidate(savedMessagesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Text(
                        'No saved messages. Use Save for later in a conversation.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              item.channelName.isEmpty
                                  ? 'Saved message'
                                  : item.channelName,
                            ),
                            subtitle: Text(
                              [
                                if (item.sender.isNotEmpty) item.sender,
                                item.channelId.isEmpty
                                    ? 'Original conversation unavailable. You can remove this saved item.'
                                    : item.preview.isEmpty
                                    ? 'Open to view the original message'
                                    : item.preview,
                              ].join(' · '),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: item.channelId.isEmpty
                                ? null
                                : () => showDialog<void>(
                                    context: context,
                                    builder: (_) => _SavedMessageDialog(
                                      item: item,
                                      orgId: ref
                                          .read(workspaceProvider)
                                          .selectedWorkspace!
                                          .id,
                                    ),
                                  ),
                            trailing: IconButton(
                              tooltip: 'Remove from Later',
                              onPressed: _pending.contains(item.id)
                                  ? null
                                  : () => _remove(item),
                              icon: const Icon(Icons.bookmark_remove_outlined),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      ),
    ],
  );
}

class _SavedMessageDialog extends ConsumerStatefulWidget {
  const _SavedMessageDialog({required this.item, required this.orgId});
  final SavedMessage item;
  final String orgId;
  @override
  ConsumerState<_SavedMessageDialog> createState() =>
      _SavedMessageDialogState();
}

class _SavedMessageDialogState extends ConsumerState<_SavedMessageDialog> {
  late Future<Map<String, dynamic>?> _message;
  late final String? _userId;
  @override
  void initState() {
    super.initState();
    _userId = ref.read(authNotifierProvider).user?.id;
    _load();
  }

  void _load() {
    final conversations =
        ref.read(dmListProvider).value ?? const <DmConversation>[];
    final dm =
        widget.item.isDm ||
        conversations.any((c) => c.channelId == widget.item.channelId);
    _message = ref.read(laterRepositoryProvider).locate(widget.item, isDm: dm);
  }

  @override
  Widget build(BuildContext context) {
    final changed =
        ref.watch(workspaceProvider).selectedWorkspace?.id != widget.orgId ||
        ref.watch(authNotifierProvider).user?.id != _userId;
    return AlertDialog(
      title: Text(
        widget.item.channelName.isEmpty
            ? 'Saved message'
            : widget.item.channelName,
      ),
      content: SizedBox(
        width: 560,
        child: changed
            ? const Text(
                'Workspace changed. Reopen Later in the selected workspace.',
              )
            : FutureBuilder<Map<String, dynamic>?>(
                future: _message,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not load the original message. It may be inaccessible, or the history search limit was reached.',
                        ),
                        TextButton(
                          onPressed: () => setState(_load),
                          child: const Text('Retry'),
                        ),
                      ],
                    );
                  }
                  final message = snapshot.data;
                  if (message == null) {
                    return const Text(
                      'This message is no longer available in the conversation. You can remove it from Later.',
                    );
                  }
                  return SingleChildScrollView(
                    child: SelectableText(
                      (message['message'] ?? message['content'] ?? '')
                          .toString(),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (!changed)
          TextButton(
            onPressed: () {
              final conversations =
                  ref.read(dmListProvider).value ?? const <DmConversation>[];
              final matching = conversations.where(
                (c) => c.channelId == widget.item.channelId,
              );
              if (matching.isNotEmpty) {
                final dm = matching.first;
                ref
                    .read(homeSidebarProvider.notifier)
                    .setType(HomeSidebarType.dms);
                if (dm.channelType.toLowerCase().contains('group')) {
                  ref
                      .read(activeChatProvider.notifier)
                      .selectGroupDm(dm.channelId);
                } else {
                  ref
                      .read(activeChatProvider.notifier)
                      .selectDirectMessage(dm.participantId);
                }
              } else if (widget.item.isDm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Conversation unavailable. Refresh your DM list.',
                    ),
                  ),
                );
                return;
              } else {
                ref
                    .read(homeSidebarProvider.notifier)
                    .setType(HomeSidebarType.home);
                ref
                    .read(activeChatProvider.notifier)
                    .selectChannel(
                      widget.item.channelName,
                      channelId: widget.item.channelId,
                    );
              }
              Navigator.pop(context);
              context.go(AppRouter.home);
            },
            child: const Text('Open conversation'),
          ),
      ],
    );
  }
}
