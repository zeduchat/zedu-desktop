import 'dart:io' show Platform;
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class DesktopWindowTitleListener extends ConsumerStatefulWidget {
  final Widget child;

  const DesktopWindowTitleListener({super.key, required this.child});

  @override
  ConsumerState<DesktopWindowTitleListener> createState() =>
      _DesktopWindowTitleListenerState();
}

class _DesktopWindowTitleListenerState
    extends ConsumerState<DesktopWindowTitleListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyTitle(ref.read(desktopWindowTitleProvider));
    });
  }

  void _applyTitle(String title) async {
    try {
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        await windowManager.setTitle(title);
      }
    } catch (e) {
      debugPrint('Failed to set window title: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(desktopWindowTitleProvider, (previous, next) {
      if (previous != next) {
        _applyTitle(next);
      }
    });
    return widget.child;
  }
}
