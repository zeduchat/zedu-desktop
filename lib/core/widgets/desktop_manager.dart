import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/domain/notification_service.dart';

class DesktopManager extends ConsumerStatefulWidget {
  final Widget child;

  const DesktopManager({super.key, required this.child});

  @override
  ConsumerState<DesktopManager> createState() => _DesktopManagerState();
}

class _DesktopManagerState extends ConsumerState<DesktopManager>
    with WindowListener, TrayListener {
  final _closeNotice = TrayCloseNotice();

  /// Whether a tray icon was put up, so the first-close notice only points at
  /// an icon that is there.
  bool _trayIconShown = false;

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
      if (Platform.isWindows) {
        await trayManager.setIcon('app_icon.ico');
        _trayIconShown = true;
      }

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
    await _closeNotice.showIfFirstClose(
      trayIconShown: _trayIconShown,
      platform: defaultTargetPlatform,
    );
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
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
