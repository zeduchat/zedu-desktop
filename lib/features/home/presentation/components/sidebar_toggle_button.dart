import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Hides or shows the main sidebar. It sits in the app bar, which the rail and
/// the shortcut keep in reach even when the sidebar is hidden.
class SidebarToggleButton extends ConsumerWidget {
  const SidebarToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final visible = ref.watch(sidebarVisibilityProvider);
    // Cmd on macOS, Ctrl elsewhere, matching the HomeView binding (#3439).
    final shortcut = defaultTargetPlatform == TargetPlatform.macOS
        ? '⌘\\'
        : 'Ctrl+\\';

    return IconButton(
      key: const Key('sidebar-toggle'),
      tooltip: visible
          ? 'Hide sidebar ($shortcut)'
          : 'Show sidebar ($shortcut)',
      onPressed: () => ref.read(sidebarVisibilityProvider.notifier).toggle(),
      icon: Icon(
        visible ? Icons.view_sidebar : Icons.view_sidebar_outlined,
        size: 20,
        color: colors.onPrimary,
      ),
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
    );
  }
}
