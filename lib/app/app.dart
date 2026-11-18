import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialise the cross-DM notification poller so notifications fire
    // even for conversations you haven't opened yet.
    ref.read(dmNotificationPollerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: kIsWeb ? 'Zedu | Team Messaging & Collaboration' : 'Zedu',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      builder: (context, child) => AppZoomShortcut(
        child: DesktopWindowTitleListener(
          child: CreditsPaymentDeepLinkListener(
            child: AuthDeepLinkListener(
              child: SessionExpiryListener(
                child: QuickSwitcherShortcut(
                  // On desktop this keeps the app in the tray: closing hides it,
                  // the tray icon and menu bring it back or quit, and desktop
                  // notifications are set up. Web has no tray, so it is left
                  // unwrapped there.
                  child: isDesktopApp
                      ? DesktopManager(child: child ?? const SizedBox.shrink())
                      : child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
