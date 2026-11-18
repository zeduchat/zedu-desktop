import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// A channel the In filter can pick.
class MessageSearchChannelOption {
  const MessageSearchChannelOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// Search every message in the workspace (#2825), narrowed by who sent it
/// (From), where (In) and when (Date). Opened from the top bar's
/// "Search messages..." box. Picking a result opens its channel.
class MessageSearchDialog extends ConsumerStatefulWidget {
  const MessageSearchDialog({
    super.key,
    required this.people,
    required this.channels,
    required this.onOpenResult,
    this.debounce = const Duration(milliseconds: 300),
  });

  /// The names the From filter offers.
  final List<String> people;

  /// The channels the In filter offers.
  final List<MessageSearchChannelOption> channels;

  /// Called with the picked result, after the dialog closes.
  final ValueChanged<SearchResultModel> onOpenResult;

  /// How long typing pauses before a search runs.
  final Duration debounce;

  @override
  ConsumerState<MessageSearchDialog> createState() =>
      _MessageSearchDialogState();
}

class _MessageSearchDialogState extends ConsumerState<MessageSearchDialog> {
  final _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  MessageSearchNotifier get _notifier =>
      ref.read(messageSearchProvider.notifier);

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () => _notifier.setText(value));
  }

  void _open(SearchResultModel result) {
    Navigator.of(context).pop();
    widget.onOpenResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(messageSearchProvider);
    final filters = state.filters;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 64, left: 24, right: 24),
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const Key('message-search-field'),
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: _notifier.setText,
                style: TextStyle(color: colors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search messages',
                  hintStyle: TextStyle(color: colors.textHint),
                  prefixIcon: Icon(Icons.search, color: colors.textSecondary),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.borderOutline),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _FilterMenu<String?>(
                    key: const Key('message-search-from'),
                    label: filters.hasFrom ? 'From: ${filters.from}' : 'From',
                    icon: Icons.person_outline,
                    active: filters.hasFrom,
                    emptyText: 'No people to pick from',
                    options: [
                      const _Option(null, 'Anyone'),
                      for (final name in widget.people) _Option(name, name),
                    ],
                    onSelected: (value) =>
                        _notifier.setFilters(filters.withFrom(value)),
                  ),
                  _FilterMenu<String?>(
                    key: const Key('message-search-in'),
                    label: filters.hasChannel
                        ? 'In: #${filters.channel}'
                        : 'In',
                    icon: Icons.tag,
                    active: filters.hasChannel,
                    emptyText: 'No channels to pick from',
                    options: [
                      const _Option(null, 'Any channel'),
                      for (final channel in widget.channels)
                        _Option(channel.name, '#${channel.name}'),
                    ],
                    onSelected: (value) =>
                        _notifier.setFilters(filters.withChannel(value)),
                  ),
                  _FilterMenu<MessageSearchDate>(
                    key: const Key('message-search-date'),
                    label: filters.hasDate ? filters.date.label : 'Date',
                    icon: Icons.calendar_today_outlined,
                    active: filters.hasDate,
                    emptyText: '',
                    options: [
                      for (final date in MessageSearchDate.values)
                        _Option(date, date.label),
                    ],
                    onSelected: (value) =>
                        _notifier.setFilters(filters.withDate(value)),
                  ),
                  if (filters.activeCount > 0)
                    TextButton(
                      key: const Key('message-search-clear'),
                      onPressed: _notifier.clearFilters,
                      child: Text(
                        filters.activeCount == 1
                            ? 'Clear filter'
                            : 'Clear ${filters.activeCount} filters',
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.divider),
            Flexible(
              child: _Results(state: state, onOpen: _open),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option<T> {
  const _Option(this.value, this.label);

  final T value;
  final String label;
}

/// One filter chip that opens a menu of choices.
class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.options,
    required this.onSelected,
    required this.emptyText,
  });

  final String label;
  final IconData icon;
  final bool active;
  final List<_Option<T>> options;
  final ValueChanged<T> onSelected;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = active ? colors.primary : colors.textSecondary;
    return PopupMenuButton<int>(
      tooltip: label,
      onSelected: (index) => onSelected(options[index].value),
      itemBuilder: (context) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem<int>(value: i, child: Text(options[i].label)),
        if (options.length <= 1 && emptyText.isNotEmpty)
          PopupMenuItem<int>(enabled: false, child: Text(emptyText)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? colors.primaryBg : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? colors.primary : colors.borderOutline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: foreground,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: foreground),
          ],
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.state, required this.onOpen});

  final MessageSearchState state;
  final ValueChanged<SearchResultModel> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    Widget message(String text, {Widget? action}) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );

    if (!state.canSearch) {
      return message('Type to search, or pick From, In or Date to narrow it.');
    }
    return state.results.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => message(
        "Couldn't search messages.",
        action: TextButton(
          onPressed: () => ref.read(messageSearchProvider.notifier).search(),
          child: const Text('Try again'),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return message(
            state.filters.activeCount > 0
                ? 'No messages match. Try removing a filter.'
                : 'No messages match.',
          );
        }
        // The API paginates, so the list ends with a control that fetches the
        // next page instead of stopping at the first one.
        final showFooter = state.hasMore || state.loadMoreFailed;

        return ListView.separated(
          key: const Key('message-search-results'),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: results.length + (showFooter ? 1 : 0),
          separatorBuilder: (_, _) => Divider(height: 1, color: colors.divider),
          itemBuilder: (context, index) {
            if (index == results.length) {
              return _LoadMoreFooter(state: state);
            }
            return _ResultTile(result: results[index], onTap: onOpen);
          },
        );
      },
    );
  }
}

/// The end of the results: fetches the next API page, or asks for another try
/// when the last attempt failed.
class _LoadMoreFooter extends ConsumerWidget {
  const _LoadMoreFooter({required this.state});

  final MessageSearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notifier = ref.read(messageSearchProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state.loadMoreFailed)
            Flexible(
              child: Text(
                "Couldn't load more results.",
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              key: const Key('message-search-load-more'),
              onPressed: state.isLoadingMore ? null : notifier.loadMore,
              child: Text(
                state.loadMoreFailed ? 'Try again' : 'Load more messages',
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});

  final SearchResultModel result;
  final ValueChanged<SearchResultModel> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final where = result.channelName.isEmpty ? '' : 'in #${result.channelName}';
    final when = result.createdAt == null
        ? ''
        : _formatWhen(result.createdAt!.toLocal());
    final meta = [where, when].where((part) => part.isNotEmpty).join(' · ');

    return InkWell(
      onTap: () => onTap(result),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    result.senderName.isEmpty ? 'Someone' : result.senderName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    meta,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              result.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatWhen(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.day} ${_months[time.month - 1]} ${time.year}, $hour:$minute';
}

/// Opens [MessageSearchDialog] with the workspace's people and channels for
/// its From and In filters (#2825). A picked channel result opens that
/// channel; any other result (a direct message) opens Direct messages.
Future<void> showMessageSearch(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _MessageSearchLoader(),
  );
}

class _MessageSearchLoader extends ConsumerWidget {
  const _MessageSearchLoader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelProvider).value ?? const <Channel>[];
    final members =
        ref.watch(peopleListProvider('')).value?.members ?? const <OrgMember>[];
    final people = <String>{
      for (final member in members)
        if (!member.deactivated && member.name.trim().isNotEmpty)
          member.name.trim(),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return MessageSearchDialog(
      people: people,
      channels: [
        for (final channel in channels)
          if (!channel.archived)
            MessageSearchChannelOption(id: channel.id, name: channel.name),
      ],
      onOpenResult: (result) {
        final channel = channels
            .where((c) => c.id == result.channelId)
            .firstOrNull;
        if (channel != null) {
          ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.home);
          ref
              .read(activeChatProvider.notifier)
              .selectChannel(channel.name, channelId: channel.id);
        } else {
          ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.dms);
        }
      },
    );
  }
}
