import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SearchPanel extends ConsumerWidget {
  final VoidCallback onClose;
  final String channelId;

  const SearchPanel({super.key, required this.onClose, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      // Mock search delay
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _results = [
            'Found message matching "$query"',
            'Another result for "$query"',
            'Older message discussing "$query"',
          ];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query = ref.watch(_searchQueryProvider);
    final results = ref.watch(_searchResultsProvider(channelId));
    final isSearching = ref.watch(_isSearchingProvider);

    return Container(
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
                  onPressed: onClose,
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
              onChanged: (value) =>
                  ref.read(_searchQueryProvider.notifier).state = value,
              onSubmitted: (_) =>
                  ref.read(_searchProvider(channelId).notifier).search(),
            ),
          ),
          Expanded(
            child: isSearching
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  )
                : results.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty ? 'Enter a search term' : 'No results found',
                      style: TextStyle(color: colors.textHint),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: results.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: colors.divider),
                    itemBuilder: (context, index) {
                      final msg = results[index];
                      return MessageBubble(
                        author: msg['sender_name'] ?? 'Someone',
                        text: msg['content'] ?? '',
                        timestamp: msg['created_at'] ?? '',
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Search query state
final _searchQueryProvider = StateProvider<String>((ref) => '');

/// Is searching state
final _isSearchingProvider = StateProvider<bool>((ref) => false);

/// Search results for a channel
final _searchResultsProvider =
    StateProvider.family<List<Map<String, dynamic>>, String>((ref, channelId) {
  return const [];
});

/// Search notifier for a channel
final _searchProvider =
    StateNotifierProvider.family<_SearchNotifier, void, String>((ref, channelId) {
  return _SearchNotifier(ref, channelId);
});

class _SearchNotifier extends StateNotifier<void> {
  final Ref _ref;
  final String _channelId;

  _SearchNotifier(this._ref, this._channelId) : super(null);

  Future<void> search() async {
    final query = _ref.read(_searchQueryProvider);
    if (query.isEmpty) {
      _ref.read(_searchResultsProvider(_channelId).notifier).state = [];
      _ref.read(_isSearchingProvider.notifier).state = false;
      return;
    }

    _ref.read(_isSearchingProvider.notifier).state = true;

    try {
      final repository = _ref.read(dmRepositoryProvider);
      final messages = await repository.getMessages(_channelId, page: 1);
      final lower = query.toLowerCase();
      final results = messages.where((m) {
        final content = (m['content'] ?? '').toString().toLowerCase();
        final sender = (m['sender_name'] ?? m['username'] ?? '').toString().toLowerCase();
        return content.contains(lower) || sender.contains(lower);
      }).toList();
      _ref.read(_searchResultsProvider(_channelId).notifier).state = results;
    } catch (_) {
      _ref.read(_searchResultsProvider(_channelId).notifier).state = [];
    } finally {
      _ref.read(_isSearchingProvider.notifier).state = false;
    }
  }
}
