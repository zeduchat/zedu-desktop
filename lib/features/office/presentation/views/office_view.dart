import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Office, the 3D office web app, inside the desktop window.
///
/// It opens on Office's `/auth/desktop` page, which asks [OfficeBridge] for
/// this app's zedu session, so the person is never asked to sign in again.
/// Links that leave Office open in the system browser instead.
class OfficeView extends ConsumerStatefulWidget {
  const OfficeView({super.key, required this.onExit});

  /// The embedded WebView exists on Windows and macOS only; elsewhere Office
  /// opens in the browser.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Called when Office asks to close, from its exit button.
  final VoidCallback onExit;

  @override
  ConsumerState<OfficeView> createState() => _OfficeViewState();
}

class _OfficeViewState extends ConsumerState<OfficeView> {
  late final OfficeBridge _bridge = OfficeBridge(
    officeUrl: kOfficeUrl,
    apiUrl: locator<AppConfig>().apiBaseUrl,
    readToken: locator<SecureStorageService>().getAccessToken,
    onExit: () => widget.onExit(),
  );

  InAppWebViewController? _controller;
  bool _loading = true;
  String? _failure;

  WebUri get _entryUrl => WebUri('$kOfficeUrl/auth/desktop');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: _entryUrl),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              isInspectable: kDebugMode,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              controller.addJavaScriptHandler(
                handlerName: OfficeBridge.handlerName,
                callback: (args) async =>
                    _bridge.handle(args, await controller.getUrl()),
              );
            },
            shouldOverrideUrlLoading: (controller, action) async {
              final url = action.request.url;
              if (url == null || _bridge.isOfficePage(url)) {
                return NavigationActionPolicy.ALLOW;
              }
              if (action.isForMainFrame) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
              return NavigationActionPolicy.CANCEL;
            },
            // Office's calls and voice rooms need the microphone and camera;
            // only Office itself is granted them.
            onPermissionRequest: (controller, request) async =>
                PermissionResponse(
                  resources: request.resources,
                  action: _bridge.isOfficePage(request.origin)
                      ? PermissionResponseAction.GRANT
                      : PermissionResponseAction.DENY,
                ),
            onLoadStop: (controller, url) {
              if (mounted) setState(() => _loading = false);
            },
            onReceivedError: (controller, request, error) {
              if (request.isForMainFrame != true || !mounted) return;
              setState(() {
                _loading = false;
                _failure =
                    'Office could not be reached. Check your '
                    'connection and try again.';
              });
            },
          ),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: colors.background,
                child: Center(
                  child: CircularProgressIndicator(color: colors.primary),
                ),
              ),
            ),
          if (_failure != null)
            Positioned.fill(
              child: _OfficeFailure(
                message: _failure!,
                onRetry: _retry,
                onExit: widget.onExit,
              ),
            ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _failure = null;
      _loading = true;
    });
    _controller?.loadUrl(urlRequest: URLRequest(url: _entryUrl));
  }
}

class _OfficeFailure extends StatelessWidget {
  const _OfficeFailure({
    required this.message,
    required this.onRetry,
    required this.onExit,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ColoredBox(
      color: colors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not open Office',
                style: context.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: context.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: onExit, child: const Text('Back')),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
