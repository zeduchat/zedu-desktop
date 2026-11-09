import 'package:zedu/core/core.dart';

/// What the notice says, per platform. The title is the same everywhere.
const trayCloseNoticeTitle = 'Zedu is still running';

/// The body of the first-close notice. It names where the way back is, and
/// that is only true where a tray icon is shown: Windows and Linux call it the
/// tray icon, macOS shows it in the menu bar.
String trayCloseNoticeBody(TargetPlatform platform) =>
    platform == TargetPlatform.macOS
    ? 'Open or quit it from the Zedu icon in the menu bar.'
    : 'Open or quit it from the tray icon.';

/// Whether to show the notice now: only the first time the window is hidden,
/// and only when a tray icon was actually put up, so it never points at an
/// icon that is not there (Ziki #167: macOS and Linux have none until the tray
/// icon is set there too).
bool shouldShowTrayCloseNotice({
  required bool trayIconShown,
  required bool alreadyShown,
}) => trayIconShown && !alreadyShown;

/// Remembers, once per install, that the notice has been shown.
abstract class TrayNoticeStore {
  Future<bool> hasShown();
  Future<void> markShown();
}

/// Keeps the flag in the app's secure storage, like the other local settings.
class SecureTrayNoticeStore implements TrayNoticeStore {
  static const storageKey = 'tray_close_notice_shown';
  static const _tag = 'SecureTrayNoticeStore';

  /// Set once it has been shown in this run, so a storage that cannot be
  /// written still shows the notice only once per run.
  bool _shownThisRun = false;

  @override
  Future<bool> hasShown() async {
    if (_shownThisRun) return true;
    try {
      return await locator<SecureStorageService>().readData(storageKey) ==
          'true';
    } catch (error) {
      // An unreadable store counts as shown: better to stay quiet than to
      // repeat the notice on every close.
      AppLogger.w('Could not read the tray notice flag - $error', tag: _tag);
      return true;
    }
  }

  @override
  Future<void> markShown() async {
    _shownThisRun = true;
    try {
      await locator<SecureStorageService>().writeData(storageKey, 'true');
    } catch (error) {
      AppLogger.w('Could not save the tray notice flag - $error', tag: _tag);
    }
  }
}

/// Shows the first-close notice once per install.
class TrayCloseNotice {
  TrayCloseNotice({
    TrayNoticeStore? store,
    Future<void> Function(String, String)? show,
  }) : _store = store ?? SecureTrayNoticeStore(),
       _show = show ?? _showDesktopNotification;

  final TrayNoticeStore _store;
  final Future<void> Function(String title, String body) _show;

  static Future<void> _showDesktopNotification(String title, String body) =>
      LocalNotification(title: title, body: body).show();

  /// Shows the notice if it is due, and remembers that it was shown. Returns
  /// whether it was shown. A failure to show never reaches the caller.
  Future<bool> showIfFirstClose({
    required bool trayIconShown,
    required TargetPlatform platform,
  }) async {
    final alreadyShown = await _store.hasShown();
    if (!shouldShowTrayCloseNotice(
      trayIconShown: trayIconShown,
      alreadyShown: alreadyShown,
    )) {
      return false;
    }
    // Marked first: a notice that fails to show is not retried on every close.
    await _store.markShown();
    try {
      await _show(trayCloseNoticeTitle, trayCloseNoticeBody(platform));
      return true;
    } catch (error) {
      AppLogger.w(
        'Could not show the tray notice - $error',
        tag: 'TrayCloseNotice',
      );
      return false;
    }
  }
}
