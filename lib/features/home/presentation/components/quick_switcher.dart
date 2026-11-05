import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// One row in the quick switcher: a channel or a direct conversation.
class QuickSwitcherEntry {
  final String label;
  final DmConversation? conversation;

  /// The channel's id, so two channels whose names differ only in case open
  /// the right one. Null for a DM.
  final String? channelId;

  const QuickSwitcherEntry.channel(this.label, {this.channelId})
    : conversation = null;

  QuickSwitcherEntry.dm(DmConversation this.conversation)
    : label = conversation.displayName,
      channelId = null;

  bool get isChannel => conversation == null;
}

/// Entries whose name contains [query], names that start with it first.
/// An empty query keeps every entry in its original order.
List<QuickSwitcherEntry> filterQuickSwitcherEntries(
  List<QuickSwitcherEntry> entries,
  String query,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return entries;

  final starts = <QuickSwitcherEntry>[];
  final contains = <QuickSwitcherEntry>[];
  for (final entry in entries) {
    final label = entry.label.toLowerCase();
    if (label.startsWith(needle)) {
      starts.add(entry);
    } else if (label.contains(needle)) {
      contains.add(entry);
    }
  }
  return [...starts, ...contains];
}

/// Search box that jumps to a channel or DM. Arrow keys move the highlight,
/// Enter opens it, Esc closes the dialog.
class QuickSwitcherDialog extends StatefulWidget {
  final List<QuickSwitcherEntry> entries;
  final ValueChanged<QuickSwitcherEntry> onSelected;

  /// Whether more entries are still on their way.
  final bool loading;

  const QuickSwitcherDialog({
    super.key,
    required this.entries,
    required this.onSelected,
    this.loading = false,
  });

  @override
  State<QuickSwitcherDialog> createState() => _QuickSwitcherDialogState();
}

class _QuickSwitcherDialogState extends State<QuickSwitcherDialog> {
  final TextEditingController _controller = TextEditingController();
  late List<QuickSwitcherEntry> _results = widget.entries;
  int _highlighted = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuickSwitcherDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.entries, oldWidget.entries)) return;

    // Entries arriving must not move the highlight to a different row, or
    // Enter would open something the user didn't pick.
    final highlighted = _results.isEmpty ? null : _results[_highlighted];
    _results = filterQuickSwitcherEntries(widget.entries, _controller.text);
    final kept = highlighted == null
        ? -1
        : _results.indexWhere(
            (entry) =>
                entry.label == highlighted.label &&
                entry.isChannel == highlighted.isChannel,
          );
    _highlighted = kept < 0 ? 0 : kept;
  }

  void _onQueryChanged(String query) {
    setState(() {
      _results = filterQuickSwitcherEntries(widget.entries, query);
      _highlighted = 0;
    });
    _revealHighlighted();
  }

  void _moveHighlight(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      _highlighted = (_highlighted + delta) % _results.length;
    });
    _revealHighlighted();
  }

  /// Scrolls just enough to show the highlighted row once the list has laid
  /// out. Every row has the same height, so its position follows from its index.
  void _revealHighlighted() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _results.isEmpty) return;
      final position = _scrollController.position;
      final viewport = position.viewportDimension;
      final rowHeight = (position.maxScrollExtent + viewport) / _results.length;
      final top = _highlighted * rowHeight;
      final bottom = top + rowHeight;

      if (top < position.pixels) {
        _scrollController.jumpTo(top);
      } else if (bottom > position.pixels + viewport) {
        _scrollController.jumpTo(bottom - viewport);
      }
    });
  }

  void _selectHighlighted() {
    if (_results.isEmpty) return;
    widget.onSelected(_results[_highlighted]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.background,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 96, left: 24, right: 24),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _moveHighlight(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _moveHighlight(-1),
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) => _selectHighlighted(),
                  style: TextStyle(color: colors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Jump to a channel or conversation',
                    hintStyle: TextStyle(color: colors.textHint),
                    prefixIcon: Icon(Icons.search, color: colors.textHint),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Divider(height: 1, color: colors.divider),
              Flexible(
                child: _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.loading ? 'Loading…' : 'No matches',
                          style: TextStyle(color: colors.textHint),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        itemCount: _results.length,
                        itemBuilder: (context, index) => _QuickSwitcherRow(
                          entry: _results[index],
                          highlighted: index == _highlighted,
                          onTap: () => widget.onSelected(_results[index]),
                        ),
                      ),
              ),
              if (widget.loading && _results.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Loading…',
                    style: TextStyle(color: colors.textHint),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickSwitcherRow extends StatelessWidget {
  final QuickSwitcherEntry entry;
  final bool highlighted;
  final VoidCallback onTap;

  const _QuickSwitcherRow({
    required this.entry,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: highlighted ? colors.primaryBg : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              entry.isChannel ? Icons.tag : Icons.person_outline,
              size: 18,
              color: colors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textPrimary, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
