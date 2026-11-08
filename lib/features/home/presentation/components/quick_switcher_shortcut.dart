import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Opens the [QuickSwitcherDialog] on Cmd+K (macOS) or Ctrl+K (Windows,
/// Linux), and the [KeyboardShortcutsDialog] on Cmd+/ or Ctrl+/, from any
/// screen once the user is signed in. Alt+Up and Alt+Down move to the
/// previous or next conversation in the Home sidebar, and Ctrl+1 to Ctrl+4
/// (Cmd+1 to Cmd+4) open the rail's Home, DMs, People and Files.
/// What Ctrl+1 to Ctrl+4 open, in the order the app rail lists them.
const _railDestinations = <HomeSidebarType>[
  HomeSidebarType.home,
  HomeSidebarType.dms,
  HomeSidebarType.people,
  HomeSidebarType.files,
];

const _railDigitKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
];

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

  /// Opens the conversation [step] places from the open one in the sidebar's
  /// order (-1 above, 1 below). It stops at either end instead of wrapping.
  void _moveConversation(int step) {
    final signedIn =
        ref.read(authNotifierProvider).status == AuthStatus.authenticated;
    if (_open || !signedIn) return;

    final entries = sidebarConversationOrder(
      channels: ref.read(channelProvider).value ?? const <Channel>[],
      orgId: ref.read(workspaceProvider).selectedWorkspace?.id,
      dms: ref.read(dmListProvider).value ?? const <DmConversation>[],
      actions: ref.read(dmConversationActionsProvider),
      ownUserId: ref.read(authNotifierProvider).user?.id,
    );
    final openIndex = openConversationIndex(
      entries,
      sidebar: ref.read(homeSidebarProvider),
      chat: ref.read(activeChatProvider),
      selectedDm: ref.read(selectedDmProvider),
    );
    final next = adjacentConversation(entries, openIndex, step);
    if (next != null) _openEntry(next);
  }

  /// Opens [destination] on the rail. From a screen that is not Home it goes
  /// to Home first, as clicking the rail icon does.
  void _openDestination(HomeSidebarType destination) {
    final signedIn =
        ref.read(authNotifierProvider).status == AuthStatus.authenticated;
    if (_open || !signedIn) return;

    ref.read(homeSidebarProvider.notifier).setType(destination);

    final location = _router.routerDelegate.currentConfiguration.uri;
    if (location.path != AppRouter.home) {
      _router.go(AppRouter.home);
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
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () =>
            _moveConversation(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () =>
            _moveConversation(1),
        for (var i = 0; i < _railDestinations.length; i++) ...{
          SingleActivator(_railDigitKeys[i], control: true): () =>
              _openDestination(_railDestinations[i]),
          SingleActivator(_railDigitKeys[i], meta: true): () =>
              _openDestination(_railDestinations[i]),
        },
        // On layouts where / needs Shift (Shift+7 on German keyboards), the
        // key bindings above never match, so match the character as well.
        const CharacterActivator('/', control: true): _showShortcuts,
        const CharacterActivator('/', meta: true): _showShortcuts,
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
            ?.where((c) => !c.archived && c.hasAccess)
            .map((c) => QuickSwitcherEntry.channel(c.name, channelId: c.id)),
        ...?dms.value?.map(QuickSwitcherEntry.dm),
      ],
      loading: channels.isLoading || dms.isLoading,
      onSelected: widget.onSelected,
    );
  }
}
