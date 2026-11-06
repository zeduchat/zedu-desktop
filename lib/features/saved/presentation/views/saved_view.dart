import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The Saved list, shown in the chat area.
class SavedView extends ConsumerStatefulWidget {
  const SavedView({super.key, this.now});

  /// Injected by tests so relative times are stable.
  final DateTime? now;

  @override
  ConsumerState<SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends ConsumerState<SavedView> {
  @override
  void initState() {
    super.initState();
    // The list is fetched when the view opens rather than by the provider, so
    // a message menu asking whether its message is saved never triggers one.
    Future.microtask(() => ref.read(savedProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final saved = ref.watch(savedProvider);
    final now = widget.now;

    // Saved items belong to an organisation, so a workspace switch reloads
    // rather than leaving another workspace's list on screen. Watched here,
    // where the workspace provider is already alive.
    ref.listen(currentOrgIdProvider, (previous, next) {
      if (previous != next) ref.read(savedProvider.notifier).refresh();
    });

    // Material, not a plain Container: the rows use InkWell, which needs a
    // Material ancestor of its own rather than relying on the host view.
    return Material(
      color: colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Row(
              children: [
                Icon(Icons.bookmark_outline, color: colors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'Saved',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  icon: Icon(Icons.refresh, color: colors.textSecondary),
                  onPressed: () => ref.read(savedProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.borderOutline),
          Expanded(child: _body(saved, now)),
        ],
      ),
    );
  }

  Widget _body(SavedState saved, DateTime? now) {
    if (saved.error != null) {
      return _Message(
        icon: Icons.error_outline,
        title: 'Could not load your saved messages.',
        detail: 'Check your connection and try again.',
        onRetry: () => ref.read(savedProvider.notifier).refresh(),
      );
    }

    if (saved.items.isEmpty) {
      if (!saved.loaded || saved.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const _Message(
        icon: Icons.bookmark_border,
        title: 'Nothing saved yet.',
        detail: 'Save a message to find it here.',
      );
    }

    return ListView.separated(
      itemCount: saved.items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.colors.borderOutline),
      itemBuilder: (_, index) {
        final item = saved.items[index];
        return SavedRow(
          item: item,
          reminder: saved.reminderFor(item.target),
          now: now,
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colors.textHint),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
