import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Opens Settings on Ctrl+, (Cmd+, on macOS), from any screen once the user is
/// signed in. It opens the same page as the Settings icon on the app rail.
class SettingsShortcut extends ConsumerWidget {
  final Widget child;

  /// The router to navigate with. Defaults to the app's router; tests pass
  /// their own.
  final GoRouter? router;

  const SettingsShortcut({super.key, required this.child, this.router});

  void _openSettings(WidgetRef ref) {
    final signedIn =
        ref.read(authNotifierProvider).status == AuthStatus.authenticated;
    if (!signedIn) return;

    final appRouter = router ?? AppRouter.router;
    final location = appRouter.routerDelegate.currentConfiguration.uri;
    if (location.path != AppRouter.profile) {
      appRouter.go(AppRouter.profile);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            _openSettings(ref),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
            _openSettings(ref),
      },
      child: child,
    );
  }
}
