import 'package:zedu/core/core.dart';

/// Installs app-wide error handling. Call once from `main()` before `runApp`.
///
/// - Framework errors (build, layout, paint) are logged with the current route.
/// - Uncaught async errors are logged instead of being dropped silently.
/// - Widgets that throw while building render [AppErrorWidget] instead of
///   Flutter's raw red/grey error box.
void installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
    AppLogger.e(
      'Unhandled framework error ${_describe(details)} on route ${currentRouteForLogs()}',
      tag: 'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.e(
      'Uncaught async error on route ${currentRouteForLogs()}',
      tag: 'PlatformDispatcher',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };

  ErrorWidget.builder = (details) => AppErrorWidget(details: details);
}

/// The current router location, or `unknown` if the router is not ready.
String currentRouteForLogs() {
  try {
    return AppRouter.router.routerDelegate.currentConfiguration.uri.toString();
  } catch (_) {
    return 'unknown';
  }
}

String _describe(FlutterErrorDetails details) {
  final where = details.context?.toDescription();
  final library = details.library;
  return [
    if (library != null) 'in $library',
    if (where != null && where.isNotEmpty) where,
  ].join(' ');
}
