import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MentionSuggestionList extends StatefulWidget {
  final List<DmParticipant> suggestions;
  final String query;
  final AppPalette colors;
  final ValueChanged<DmParticipant> onSelect;

  /// The row the keyboard has highlighted (Up/Down in the composer); Enter
  /// or Tab there inserts it. Null highlights nothing.
  final int? selectedIndex;

  const MentionSuggestionList({
    super.key,
    required this.suggestions,
    required this.query,
    required this.colors,
    required this.onSelect,
    this.selectedIndex,
  });

  @override
  State<MentionSuggestionList> createState() => _MentionSuggestionListState();
}

class _MentionSuggestionListState extends State<MentionSuggestionList> {
  final _scrollController = ScrollController();
  final _selectedRowKey = GlobalKey();

  @override
  void didUpdateWidget(MentionSuggestionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  /// Keeps the highlighted row in view as the keyboard moves through a list
  /// taller than the popup, including when it wraps from one end to the other.
  void _revealSelected() {
    if (!mounted || !_scrollController.hasClients) return;
    final index = widget.selectedIndex;
    if (index == null) return;
    final position = _scrollController.position;
    if (index == 0) {
      position.jumpTo(position.minScrollExtent);
    } else if (index == widget.suggestions.length - 1) {
      position.jumpTo(position.maxScrollExtent);
    }
    final rowContext = _selectedRowKey.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      Scrollable.ensureVisible(
        rowContext,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.suggestions;
    final colors = widget.colors;
    final onSelect = widget.onSelect;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'People',
              style: TextStyle(
                color: colors.textHint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 6),
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final p = suggestions[index];
                final initial = avatarInitial(p.username);
                final isSelected = index == widget.selectedIndex;
                // One announced, actionable item per person (Ziki #590).
                return Semantics(
                  key: isSelected ? _selectedRowKey : null,
                  button: true,
                  selected: isSelected ? true : null,
                  label: 'Mention @${p.username}',
                  excludeSemantics: true,
                  onTap: () => onSelect(p),
                  child: InkWell(
                    onTap: () => onSelect(p),
                    hoverColor: colors.primary.withValues(alpha: 0.07),
                    child: Container(
                      color: isSelected
                          ? colors.primary.withValues(alpha: 0.12)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: colors.primary,
                            backgroundImage:
                                p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                                ? NetworkImage(p.avatarUrl!)
                                : null,
                            child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          // Long usernames and emails are ellipsized instead
                          // of overflowing the row.
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  p.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (p.email.isNotEmpty)
                                  Text(
                                    p.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textHint,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
