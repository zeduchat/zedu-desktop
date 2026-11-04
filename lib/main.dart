import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import 'package:zedu/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalErrorHandlers();
  await windowManager.ensureInitialized();
  await loadAppEnv();
  setupLocator();

  runApp(
    ProviderScope(
      // core only knows the DesktopNotifier interface (AGENTS.md forbids
      // lib/core from importing a feature), so the dms implementation is
      // wired here, at the composition root.
      overrides: [
        desktopNotifierProvider.overrideWith(
          (ref) => ref.watch(notificationServiceProvider),
        ),
      ],
      child: const App(),
    ),
  );
}
