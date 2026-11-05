import 'package:zedu/core/core.dart';
import 'package:zedu/app/app.dart';
import 'package:zedu/core/window/window_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalErrorHandlers();
  await windowManager.ensureInitialized();
  await loadAppEnv();
  setupLocator();
  await WindowBoundsController(
    window: windowManager,
    storage: locator<SecureStorageService>(),
  ).restore();
  showWindowWhenReady(windowManager);

  runApp(const ProviderScope(child: App()));
}
