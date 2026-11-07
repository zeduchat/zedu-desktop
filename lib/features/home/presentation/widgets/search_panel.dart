import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Searches one conversation's full history on the server.
class SearchPanel extends ConsumerStatefulWidget {
  final String channelId;
  final VoidCallback onClose;

  const SearchPanel({
    super.key,
    required this.channelId,
    required this.onClose,
  });

  @override
  ConsumerState<SearchPanel> createState() => SearchPanelState();
}

class SearchPanelState extends ConsumerState<SearchPanel> {
  static const _debounce = Duration(milliseconds: 300);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'SearchPanel field');
  Timer? _debounceTimer;
  List<ConversationSearchHit> _results = [];
  bool _isSearching = false;
  bool _failed = false;
  String _searchedQuery = '';
  // Only the latest request may update the panel; slower older ones are
  // dropped so their results never replace newer ones.
  int _requestId = 0;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  /// Puts the cursor back in the search field with its text selected, for
  /// Cmd/Ctrl+F while the panel is already open (Ziki #3441).
  void focusField() {
    _fieldFocus.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _performSearch(value));
  }

  Future<void> _performSearch(String value) async {
    _debounceTimer?.cancel();
    final query = value.trim();
    final requestId = ++_requestId;
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _failed = false;
        _searchedQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _failed = false;
    });
    try {
      final hits = await ref
          .read(dmRepositoryProvider)
          .searchMessages(channelId: widget.channelId, query: query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = hits;
        _isSearching = false;
        _searchedQuery = query;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = [];
        _isSearching = false;
        _failed = true;
        _searchedQuery = query;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Esc anywhere in the panel closes it, like the close button (#3441).
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(left: BorderSide(color: colors.divider)),
        ),
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close, color: colors.textHint),
                    splashRadius: 20,
                    tooltip: 'Close search',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                focusNode: _fieldFocus,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: colors.textHint),
                  prefixIcon: Icon(Icons.search, color: colors.textHint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onChanged: _onChanged,
                onSubmitted: _performSearch,
              ),
            ),
            Expanded(child: _buildResults(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AppPalette colors) {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't search messages.",
              style: TextStyle(color: colors.textHint),
            ),
            TextButton(
              onPressed: () => _performSearch(_searchedQuery),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _searchedQuery.isEmpty
              ? 'Enter a search term'
              : 'No messages match "$_searchedQuery"',
          style: TextStyle(color: colors.textHint),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (context, index) => Divider(color: colors.divider),
      itemBuilder: (context, index) {
        final hit = _results[index];
        final sentAt = hit.sentAtLabel;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sentAt == null ? hit.userName : '${hit.userName} · $sentAt',
              style: TextStyle(fontSize: 12, color: colors.textHint),
            ),
            const SizedBox(height: 4),
            Text.rich(
              highlightMatches(
                hit.text,
                _searchedQuery,
                base: TextStyle(color: colors.textPrimary),
                match: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  backgroundColor: colors.primary.withValues(alpha: 0.18),
                ),
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

/// Splits [text] so every case-insensitive occurrence of [query] uses [match].
@visibleForTesting
TextSpan highlightMatches(
  String text,
  String query, {
  required TextStyle base,
  required TextStyle match,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return TextSpan(text: text, style: base);
  final haystack = text.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final index = haystack.indexOf(needle, start);
    if (index < 0) break;
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index)));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + needle.length),
        style: match,
      ),
    );
    start = index + needle.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return TextSpan(style: base, children: spans);
}
