import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Opens the [QuickSwitcherDialog] on Cmd+K (macOS) or Ctrl+K (Windows,
/// Linux), and the [KeyboardShortcutsDialog] on Cmd+/ or Ctrl+/, from any
/// screen once the user is signed in.
class QuickSwitcherShortcut extends ConsumerStatefulWidget {
  final Widget child;

  /// The router to open the switcher over and to navigate with. Defaults to
  /// the app's router; tests pass their own.
  final GoRouter? router;

  const QuickSwitcherShortcut({super.key, required this.child, this.router});

  @override
  ConsumerState<QuickSwitcherShortcut> createState() =>
      _QuickSwitcherShortcutState();
}

class _QuickSwitcherShortcutState extends ConsumerState<QuickSwitcherShortcut> {
  bool _open = false;

  GoRouter get _router => widget.router ?? AppRouter.router;

  Future<void> _showSwitcher() async {
    final signedIn =
        ref.read(authNotifierProvider).status == AuthStatus.authenticated;
    final navigatorContext = _router.routerDelegate.navigatorKey.currentContext;
    if (_open || !signedIn || navigatorContext == null) return;

    _open = true;
    try {
      await showDialog<void>(
        context: navigatorContext,
        builder: (dialogContext) => _QuickSwitcherLoader(
          onSelected: (entry) {
            Navigator.of(dialogContext).pop();
            _openEntry(entry);
          },
        ),
      );
    } finally {
      _open = false;
    }
  }

  Future<void> _showShortcuts() async {
    final signedIn =
        ref.read(authNotifierProvider).status == AuthStatus.authenticated;
    final navigatorContext = _router.routerDelegate.navigatorKey.currentContext;
    if (_open || !signedIn || navigatorContext == null) return;

    _open = true;
    try {
      await showDialog<void>(
        context: navigatorContext,
        builder: (_) => const KeyboardShortcutsDialog(),
      );
    } finally {
      _open = false;
    }
  }

  void _openEntry(QuickSwitcherEntry entry) {
    final conversation = entry.conversation;
    if (conversation == null) {
      ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.home);
      ref
          .read(activeChatProvider.notifier)
          .selectChannel(entry.label, channelId: entry.channelId);
    } else {
      ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.dms);
      ref.read(selectedDmProvider.notifier).select(conversation);
    }

    final location = _router.routerDelegate.currentConfiguration.uri;
    if (location.path != AppRouter.home) {
      _router.go(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showSwitcher,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _showSwitcher,
        const SingleActivator(LogicalKeyboardKey.slash, control: true):
            _showShortcuts,
        const SingleActivator(LogicalKeyboardKey.slash, meta: true):
            _showShortcuts,
      },
      child: widget.child,
    );
  }
}

/// Shows the switcher at once with whatever has loaded, and fills in as the
/// lists arrive. A list that fails to load is left out, and the user is told,
/// so a short list isn't mistaken for all of them.
class _QuickSwitcherLoader extends ConsumerStatefulWidget {
  final ValueChanged<QuickSwitcherEntry> onSelected;

  const _QuickSwitcherLoader({required this.onSelected});

  @override
  ConsumerState<_QuickSwitcherLoader> createState() =>
      _QuickSwitcherLoaderState();
}

class _QuickSwitcherLoaderState extends ConsumerState<_QuickSwitcherLoader> {
  bool _toldLoadFailed = false;

  void _tellLoadFailed() {
    if (_toldLoadFailed) return;
    _toldLoadFailed = true;
    // The dialog sits inside the navigator's overlay, so the toast is shown
    // from its context once it is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: "Couldn't load all your channels and DMs.",
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(channelProvider);
    final dms = ref.watch(dmListProvider);
    if (channels.hasError || dms.hasError) _tellLoadFailed();

    return QuickSwitcherDialog(
      entries: [
        ...?channels.value
            ?.where((c) => !c.archived)
            .map((c) => QuickSwitcherEntry.channel(c.name, channelId: c.id)),
        ...?dms.value?.map(QuickSwitcherEntry.dm),
      ],
      loading: channels.isLoading || dms.isLoading,
      onSelected: widget.onSelected,
    );
  }
}
