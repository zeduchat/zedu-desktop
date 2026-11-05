import 'package:zedu/core/core.dart';

/// Closes the current dialog on Escape without navigating away from a page.
class DialogEscapeShortcut extends StatelessWidget {
  const DialogEscapeShortcut({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _dismissDialog,
      },
      child: child,
    );
  }

  void _dismissDialog() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) return;

    final route = ModalRoute.of(focusedContext);
    if (route is PopupRoute && route.isCurrent) {
      Navigator.of(focusedContext).maybePop();
    }
  }
}
