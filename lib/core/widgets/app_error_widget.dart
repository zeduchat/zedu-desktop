import 'package:zedu/core/core.dart';

/// Shown in place of a widget that threw while building
/// (installed as [ErrorWidget.builder] by `installGlobalErrorHandlers`).
///
/// Keeps the failure contained to the broken region and offers a retry that
/// rebuilds the widget that failed, or a way back to home. Error details are
/// only shown in debug.
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({super.key, required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = Material(
      type: MaterialType.transparency,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colors.error, size: 24),
              const SizedBox(height: 8),
              Text(
                'Something went wrong here.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 4),
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textHint,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _retry(context),
                    child: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () => AppRouter.router.go(AppRouter.home),
                    child: const Text('Back to home'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // The error can surface above MaterialApp, where there is no Directionality.
    if (Directionality.maybeOf(context) == null) {
      return Directionality(textDirection: TextDirection.ltr, child: content);
    }
    return content;
  }

  /// Rebuilds the element that failed, which re-runs its build.
  void _retry(BuildContext context) {
    context.visitAncestorElements((element) {
      element.markNeedsBuild();
      return false;
    });
  }
}
