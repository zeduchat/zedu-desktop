import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The toast text for a failed archive or unarchive.
String archiveFailureMessage(
  ApiFailure error,
  Channel channel, {
  required bool archived,
}) {
  final action = archived ? 'archive' : 'unarchive';
  return switch (error.kind) {
    ApiFailureKind.forbidden =>
      'Only the channel owner or an admin can $action #${channel.name}.',
    ApiFailureKind.unknown || ApiFailureKind.parsing =>
      'Could not $action #${channel.name}. Please try again.',
    _ =>
      error.friendlyMessage.isEmpty
          ? 'Could not $action #${channel.name}'
          : error.friendlyMessage,
  };
}

/// The channel directory's archived channels, each with an Unarchive button.

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The toast text for a failed archive or unarchive.
String archiveFailureMessage(
  ApiFailure error,
  Channel channel, {
  required bool archived,
}) {
  final action = archived ? 'archive' : 'unarchive';
  return switch (error.kind) {
    ApiFailureKind.forbidden =>
      'Only the channel owner or an admin can $action #${channel.name}.',
    ApiFailureKind.unknown || ApiFailureKind.parsing =>
      'Could not $action #${channel.name}. Please try again.',
    _ =>
      error.friendlyMessage.isEmpty
          ? 'Could not $action #${channel.name}'
          : error.friendlyMessage,
  };
}

/// The channel directory's archived channels, each with an Unarchive button.

class ChannelManagementSection extends ConsumerStatefulWidget {
  const ChannelManagementSection({super.key});
  @override
  ConsumerState<ChannelManagementSection> createState() =>
      _ChannelManagementSectionState();
}

class _ChannelManagementSectionState
    extends ConsumerState<ChannelManagementSection> {
  String _query = '';
  bool _archived = false;
  int _page = 0;
  final _pending = <String>{};
  String? _error;
  static const _pageSize = 20;

  Future<void> _archive(Channel channel, String orgId) async {
    if (_pending.contains(channel.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${channel.archived ? "Unarchive" : "Archive"} #${channel.name}?',
        ),
        content: Text(
          channel.archived
              ? 'This channel will become active again.'
              : 'This channel becomes read-only and leaves the active sidebar. Its history is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        ref.read(workspaceProvider).selectedWorkspace?.id != orgId) {
      return;
    }
    setState(() {
      _pending.add(channel.id);
      _error = null;
    });
    try {
      final result = await ref
          .read(channelRepositoryProvider)
          .archiveChannel(channel.id, !channel.archived);
      if (!mounted ||
          ref.read(workspaceProvider).selectedWorkspace?.id != orgId) {
        return;
      }
      if (result is Failure<void>) {
        setState(
          () => _error = archiveFailureMessage(
            result.error,
            channel,
            archived: !channel.archived,
          ),
        );
      } else {
        ref.invalidate(managedChannelsProvider);
        ref.invalidate(channelProvider);
        ref.invalidate(archivedChannelsProvider);
      }
    } finally {
      if (mounted) setState(() => _pending.remove(channel.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgId = ref.watch(workspaceProvider).selectedWorkspace?.id;
    ref.listen(workspaceProvider.select((s) => s.selectedWorkspace?.id), (
      _,
      _,
    ) {
      setState(() {
        _error = null;
        _page = 0;
        _pending.clear();
      });
    });
    if (orgId == null) {
      return const Text('Select a workspace to manage channels.');
    }
    final state = ref.watch(managedChannelsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(
          title: 'Channel Management',
          subtitle: 'Manage channels you are authorized to access.',
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search channels',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() {
            _query = v.trim().toLowerCase();
            _page = 0;
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final archived in [false, true])
              ChoiceChip(
                label: Text(archived ? 'Archived' : 'Active'),
                selected: _archived == archived,
                onSelected: (_) => setState(() {
                  _archived = archived;
                  _page = 0;
                }),
              ),
          ],
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: context.colors.error)),
        const SizedBox(height: 16),
        state.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error is ApiFailure
                    ? error.friendlyMessage
                    : 'Could not load channels.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(managedChannelsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (all) {
            final channels =
                all
                    .where(
                      (m) =>
                          m.channel.archived == _archived &&
                          m.channel.name.toLowerCase().contains(_query),
                    )
                    .toList()
                  ..sort((a, b) => a.channel.name.compareTo(b.channel.name));
            if (channels.isEmpty) {
              return const Text('No channels match your filters.');
            }
            final pages = (channels.length / _pageSize).ceil();
            final page = _page.clamp(0, pages - 1);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Channel')),
                      DataColumn(label: Text('Visibility')),
                      DataColumn(label: Text('Members')),
                      DataColumn(label: Text('Created')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: channels
                        .skip(page * _pageSize)
                        .take(_pageSize)
                        .map(
                          (m) => DataRow(
                            cells: [
                              DataCell(Text('#${m.channel.name}')),
                              DataCell(
                                Text(
                                  m.channel.isPrivate ? 'Private' : 'Public',
                                ),
                              ),
                              DataCell(
                                Text(
                                  m.memberCount?.toString() ?? 'Unavailable',
                                ),
                              ),
                              DataCell(
                                Text(
                                  m.createdAt == null
                                      ? 'Unavailable'
                                      : formatFileDate(m.createdAt!.toLocal()),
                                ),
                              ),
                              DataCell(
                                TextButton(
                                  onPressed: _pending.contains(m.channel.id)
                                      ? null
                                      : () => _archive(m.channel, orgId),
                                  child: Text(
                                    _pending.contains(m.channel.id)
                                        ? 'Saving…'
                                        : m.channel.archived
                                        ? 'Unarchive'
                                        : 'Archive',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous page',
                      onPressed: page == 0
                          ? null
                          : () => setState(() => _page = page - 1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('Page ${page + 1} of $pages'),
                    IconButton(
                      tooltip: 'Next page',
                      onPressed: page + 1 >= pages
                          ? null
                          : () => setState(() => _page = page + 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
