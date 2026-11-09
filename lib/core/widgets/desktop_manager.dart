import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/domain/notification_service.dart';

/// Whether the app runs as a desktop app, where [DesktopManager] is mounted.
bool get isDesktopApp =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// The tray icon, as a bundled asset: the tray plugin looks icons up in the
/// app's assets. Windows needs an .ico; macOS and Linux take a PNG.
String trayIconAsset(TargetPlatform platform) =>
    platform == TargetPlatform.windows
    ? 'assets/pngs/tray_icon.ico'
    : 'assets/pngs/zedu_logo.png';

/// Keeps the desktop app running in the tray: closing the window hides it,
/// the tray icon and menu bring it back or quit, and desktop notifications are
/// set up.
class DesktopManager extends ConsumerStatefulWidget {
  final Widget child;

  const DesktopManager({super.key, required this.child});

  @override
  ConsumerState<DesktopManager> createState() => _DesktopManagerState();
}

class _DesktopManagerState extends ConsumerState<DesktopManager>
    with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initDesktop();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initDesktop() async {
    // Make sure window doesn't close completely when clicking X
    try {
      await windowManager.setPreventClose(true);
    } catch (e) {
      debugPrint('Failed to setPreventClose: $e');
    }

    try {
      await trayManager.setIcon(trayIconAsset(defaultTargetPlatform));

      Menu menu = Menu(
        items: [
          MenuItem(key: 'show_window', label: 'Show Zedu'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: 'Exit'),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('Tray manager init failed: $e');
    }

    try {
      await ref.read(notificationServiceProvider).init();
    } catch (e) {
      debugPrint('Local notifier setup failed: $e');
    }
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      // Closing is prevented so X can hide to the tray; Exit must really quit.
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
