import 'package:zedu/core/core.dart';

/// The colour mode picked in Settings → Appearance: light, dark, or the
/// system setting (Auto). Kept on this computer across launches.
class AppThemeModeNotifier extends Notifier<ThemeMode> {
  static const storageKey = 'app_theme_mode';
  static const _tag = 'AppThemeModeNotifier';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  /// A locked or unavailable keychain keeps following the system instead of
  /// failing at startup.
  Future<void> _restore() async {
    final String? raw;
    try {
      raw = await locator<SecureStorageService>().readData(storageKey);
    } catch (error) {
      AppLogger.w('Could not read the saved theme mode - $error', tag: _tag);
      return;
    }
    for (final mode in ThemeMode.values) {
      if (mode.name == raw) {
        state = mode;
        return;
      }
    }
  }

  /// Applies [mode] at once. If it can't be saved, it still holds for this
  /// session.
  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await locator<SecureStorageService>().writeData(storageKey, mode.name);
    } catch (error) {
      AppLogger.w('Could not save the theme mode - $error', tag: _tag);
    }
  }
}

final appThemeModeProvider = NotifierProvider<AppThemeModeNotifier, ThemeMode>(
  AppThemeModeNotifier.new,
);
