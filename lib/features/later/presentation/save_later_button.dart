import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SaveLaterButton extends ConsumerStatefulWidget {
  const SaveLaterButton({
    super.key,
    required this.channelId,
    required this.threadId,
  });
  final String channelId;
  final String threadId;
  @override
  ConsumerState<SaveLaterButton> createState() => _SaveLaterButtonState();
}

class _SaveLaterButtonState extends ConsumerState<SaveLaterButton> {
  bool _busy = false;
  Future<void> _toggle(bool saved) async {
    if (_busy) return;
    final org = ref.read(workspaceProvider).selectedWorkspace?.id;
    final user = ref.read(authNotifierProvider).user?.id;
    if (org == null || user == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(laterRepositoryProvider);
      if (saved) {
        await repo.remove(org, widget.threadId);
      } else {
        await repo.save(org, widget.channelId, widget.threadId);
      }
      if (!mounted ||
          ref.read(workspaceProvider).selectedWorkspace?.id != org ||
          ref.read(authNotifierProvider).user?.id != user) {
        return;
      }
      ref.invalidate(savedMessagesProvider);
    } catch (_) {
      if (mounted && ref.read(workspaceProvider).selectedWorkspace?.id == org) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update saved messages. Retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedMessagesProvider);
    final saved =
        state.value?.any((item) => item.id == widget.threadId) ?? false;
    return IconButton(
      tooltip: state.hasError
          ? 'Could not load bookmarks. Retry'
          : saved
          ? 'Remove from Later'
          : 'Save for later',
      onPressed: _busy || state.isLoading
          ? null
          : state.hasError
          ? () => ref.invalidate(savedMessagesProvider)
          : () => _toggle(saved),
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
    );
  }
}
