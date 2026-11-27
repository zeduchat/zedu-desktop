import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Ctrl/Cmd + and - zoom the app text, Ctrl/Cmd 0 resets it. + works as `=`,
/// Shift+`=`, a dedicated `+` key or numpad +. The zoom level is applied as a
/// text scale to everything below.
class AppZoomShortcut extends ConsumerWidget {
  final Widget child;

  const AppZoomShortcut({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(appZoomProvider);
    final notifier = ref.read(appZoomProvider.notifier);
    final media = MediaQuery.of(context);

    return CallbackShortcuts(
      bindings: {
        for (final key in [
          LogicalKeyboardKey.equal,
          LogicalKeyboardKey.numpadAdd,
          LogicalKeyboardKey.add,
        ]) ...{
          SingleActivator(key, control: true): notifier.zoomIn,
          SingleActivator(key, meta: true): notifier.zoomIn,
        },
        // `+` is Shift+= on US/UK keyboards, and a dedicated `+` key may be
        // pressed with Shift too.
        for (final key in [
          LogicalKeyboardKey.equal,
          LogicalKeyboardKey.add,
        ]) ...{
          SingleActivator(key, control: true, shift: true): notifier.zoomIn,
          SingleActivator(key, meta: true, shift: true): notifier.zoomIn,
        },
        for (final key in [
          LogicalKeyboardKey.minus,
          LogicalKeyboardKey.numpadSubtract,
        ]) ...{
          SingleActivator(key, control: true): notifier.zoomOut,
          SingleActivator(key, meta: true): notifier.zoomOut,
        },
        SingleActivator(LogicalKeyboardKey.digit0, control: true):
            notifier.reset,
        SingleActivator(LogicalKeyboardKey.digit0, meta: true): notifier.reset,
      },
      child: Focus(
        autofocus: true,
        child: MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(zoom * media.textScaler.scale(1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
