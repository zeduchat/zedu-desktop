import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Tray menu keys.
const trayShowWindowKey = 'show_window';
const trayExitKey = 'exit_app';
const trayPauseNotificationsKey = 'pause_notifications';
const trayResumeNotificationsKey = 'resume_notifications';

/// How long "Pause notifications for 1 hour" pauses them for.
const trayPauseDuration = Duration(hours: 1);

/// The tray menu: Show, a Pause or Resume item for notifications, and Exit.
/// [paused] says whether notifications are paused right now (the same pause
/// the user menu sets), so the menu offers Resume instead of Pause.
Menu buildTrayMenu({required bool paused}) {
  return Menu(
    items: [
      MenuItem(key: trayShowWindowKey, label: 'Show Zedu'),
      MenuItem.separator(),
      paused
          ? MenuItem(
              key: trayResumeNotificationsKey,
              label: 'Resume notifications',
            )
          : MenuItem(
              key: trayPauseNotificationsKey,
              label: 'Pause notifications for 1 hour',
            ),
      MenuItem.separator(),
      MenuItem(key: trayExitKey, label: 'Exit'),
    ],
  );
}

/// Pauses or resumes notifications for the tray item with [key], through the
/// same settings the user menu uses. Returns whether [key] was one of them.
bool applyTrayNotificationAction(
  String? key,
  NotificationSettingsNotifier notifier,
) {
  switch (key) {
    case trayPauseNotificationsKey:
      notifier.setDndMode(trayPauseDuration);
      return true;
    case trayResumeNotificationsKey:
      notifier.clearDndMode();
      return true;
  }
  return false;
}

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
    // The pause can start or end anywhere (user menu, this menu, running
    // out), so the tray menu follows the setting.
    ref.listenManual(
      notificationSettingsProvider.select((settings) => settings.isDndActive),
      (_, _) => _updateTrayMenu(),
    );
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
      }

      await trayManager.setContextMenu(
        buildTrayMenu(
          paused: ref.read(notificationSettingsProvider).isDndActive,
        ),
      );
    } catch (e) {
      debugPrint('Tray manager init failed: $e');
    }

    try {
      await ref.read(notificationServiceProvider).init();
    } catch (e) {
      debugPrint('Local notifier setup failed: $e');
    }
  }

  Future<void> _updateTrayMenu() async {
    try {
      await trayManager.setContextMenu(
        buildTrayMenu(
          paused: ref.read(notificationSettingsProvider).isDndActive,
        ),
      );
    } catch (e) {
      debugPrint('Tray menu update failed: $e');
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
    if (menuItem.key == trayShowWindowKey) {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == trayExitKey) {
      await windowManager.destroy();
    } else {
      applyTrayNotificationAction(
        menuItem.key,
        ref.read(notificationSettingsProvider.notifier),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
