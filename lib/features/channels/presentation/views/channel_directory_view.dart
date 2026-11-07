import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ChannelDirectoryView extends ConsumerStatefulWidget {
  const ChannelDirectoryView({super.key});

  @override
  ConsumerState<ChannelDirectoryView> createState() =>
      _ChannelDirectoryViewState();
}

class _ChannelDirectoryViewState extends ConsumerState<ChannelDirectoryView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showArchived = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Opens the same create-channel dialog the sidebar's "Add channel" action
  /// uses (home_view.dart `_AddChannelButton`), so the directory offers a way
  /// to create the channel a search could not find. On success
  /// `ChannelNotifier.createChannel` inserts the new channel into the state
  /// this view watches, so the list updates without an extra reload.
  void _openCreateChannel() {
    showDialog<void>(
      context: context,
      builder: (_) => const CreateChannelModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelState = ref.watch(channelProvider);
    final colors = context.colors;
    final textTheme = context.textTheme;

    final channels = channelState.value ?? const <Channel>[];
    final filteredChannels = channels.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Channel Directory',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _openCreateChannel,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New channel'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search channels',
              prefixIcon: Icon(Icons.search, color: colors.textHint),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.divider),
              ),
            ),
            style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Channels'),
                selected: !_showArchived,
                onSelected: (_) => setState(() => _showArchived = false),
              ),
              ChoiceChip(
                label: const Text('Archived'),
                selected: _showArchived,
                onSelected: (_) => setState(() => _showArchived = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _showArchived
              ? ArchivedChannelList(searchQuery: _searchQuery)
              : channelState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : channelState.hasError && !channelState.hasValue
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Couldn't load channels",
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(channelProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : filteredChannels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No channels found.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openCreateChannel,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create a channel'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredChannels.length,
                  itemBuilder: (context, index) {
                    final channel = filteredChannels[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: channel.isPrivate
                              ? Icon(
                                  Icons.lock,
                                  size: 20,
                                  color: colors.textSecondary,
                                )
                              : Text(
                                  '#',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        channel.name,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: channel.description.isNotEmpty
                          ? Text(
                              channel.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                              ),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (channel.unreadCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${channel.unreadCount}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onError,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            channel.membersCount.countLabel('member'),
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          if (!channel.hasAccess &&
                              !channel.archived &&
                              !channel.isPrivate) ...[
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () async {
                                final result = await ref
                                    .read(channelProvider.notifier)
                                    .joinChannel(channel.id);
                                if (result is Success<void> &&
                                    context.mounted) {
                                  ref
                                      .read(activeChatProvider.notifier)
                                      .selectChannel(
                                        channel.name,
                                        channelId: channel.id,
                                      );
                                }
                              },
                              child: const Text('Join'),
                            ),
                          ],
                        ],
                      ),
                      onTap: () async {
                        if (!channel.hasAccess &&
                            !channel.archived &&
                            !channel.isPrivate) {
                          final result = await ref
                              .read(channelProvider.notifier)
                              .joinChannel(channel.id);
                          if (result is Success<void> && context.mounted) {
                            ref
                                .read(activeChatProvider.notifier)
                                .selectChannel(
                                  channel.name,
                                  channelId: channel.id,
                                );
                          }
                          return;
                        }
                        ref
                            .read(activeChatProvider.notifier)
                            .selectChannel(channel.name, channelId: channel.id);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
