import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// What Ctrl+1 to Ctrl+4 (Cmd+1 to Cmd+4 on macOS) open, in the order the
/// app rail lists them: Home, DMs, People, Files.
const railShortcutDestinations = <HomeSidebarType>[
  HomeSidebarType.home,
  HomeSidebarType.dms,
  HomeSidebarType.people,
  HomeSidebarType.files,
];

const _digitKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
];

/// Opens Home, DMs, People or Files on Ctrl+1 to Ctrl+4 (Cmd on macOS), from
/// any screen once the user is signed in. From a screen that is not Home it
/// goes to Home first, as clicking the rail icon does.
class RailNumberShortcuts extends ConsumerWidget {
  final Widget child;

  /// The router to navigate with. Defaults to the app's router; tests pass
  /// their own.
  final GoRouter? router;

  const RailNumberShortcuts({super.key, required this.child, this.router});

  void _open(WidgetRef ref, HomeSidebarType destination) {
    final signedIn =
        ref.read(authNotifierProvider).status == AuthStatus.authenticated;
    if (!signedIn) return;

    ref.read(homeSidebarProvider.notifier).setType(destination);

    final appRouter = router ?? AppRouter.router;
    final location = appRouter.routerDelegate.currentConfiguration.uri;
    if (location.path != AppRouter.home) {
      appRouter.go(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < railShortcutDestinations.length; i++) ...{
          SingleActivator(_digitKeys[i], control: true): () =>
              _open(ref, railShortcutDestinations[i]),
          SingleActivator(_digitKeys[i], meta: true): () =>
              _open(ref, railShortcutDestinations[i]),
        },
      },
      child: child,
    );
  }
}
