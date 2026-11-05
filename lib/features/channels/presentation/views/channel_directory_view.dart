import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ChannelDirectoryView extends ConsumerStatefulWidget {
  const ChannelDirectoryView({super.key});

  @override
  ConsumerState<ChannelDirectoryView> createState() =>
      _ChannelDirectoryViewState();
}

/// The channels whose name or description contains [query], ignoring case
/// and any spaces around the query, so a pasted " general " still finds
/// #general. An empty or blank query keeps every channel.
@visibleForTesting
List<Channel> filterChannels(List<Channel> channels, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return channels;
  return channels
      .where(
        (c) =>
            c.name.toLowerCase().contains(needle) ||
            c.description.toLowerCase().contains(needle),
      )
      .toList();
}

class _ChannelDirectoryViewState extends ConsumerState<ChannelDirectoryView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelState = ref.watch(channelProvider);
    final colors = context.colors;
    final textTheme = context.textTheme;

    final channels = channelState.value ?? const <Channel>[];
    final filteredChannels = filterChannels(channels, _searchQuery);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Channel Directory',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
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
        const SizedBox(height: 16),
        Expanded(
          child: channelState.isLoading
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
                  child: Text(
                    'No channels found.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
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
                      trailing: Text(
                        channel.membersCount.countLabel('member'),
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      onTap: () {
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
