import 'package:zedu/core/core.dart';

/// The only part of desktop notifications that `lib/core` may depend on.
///
/// `AGENTS.md` forbids `lib/core` from importing `features.dart`, so the boot
/// widget reads this interface instead of the dms `NotificationService`. The
/// feature that owns notifications implements it and wires the implementation
/// at the app's composition root (`main.dart`).
abstract interface class DesktopNotifier {
  /// Prepares the platform notification channel. Called once at boot.
  Future<void> init();
}

/// Used until a feature registers a real notifier: tests, and any build where
/// desktop notifications are not wired.
class NoopDesktopNotifier implements DesktopNotifier {
  const NoopDesktopNotifier();

  @override
  Future<void> init() async {}
}

/// Overridden at the composition root by the feature that owns notifications.
final desktopNotifierProvider = Provider<DesktopNotifier>(
  (ref) => const NoopDesktopNotifier(),
);
