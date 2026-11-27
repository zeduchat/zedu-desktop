import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class CreditsPaymentDeepLinkListener extends ConsumerStatefulWidget {
  const CreditsPaymentDeepLinkListener({
    super.key,
    required this.child,
    this.appLinks,
  });

  final Widget child;
  final AppLinks? appLinks;

  @override
  ConsumerState<CreditsPaymentDeepLinkListener> createState() =>
      _CreditsPaymentDeepLinkListenerState();
}

class _CreditsPaymentDeepLinkListenerState
    extends ConsumerState<CreditsPaymentDeepLinkListener> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final _pendingSessions = <String>{};
  final _verifyingSessions = <String>{};
  final _verifiedSessions = <String>{};

  static const _tag = 'CreditsPaymentDeepLinkListener';

  @override
  void initState() {
    super.initState();
    _appLinks = widget.appLinks ?? AppLinks();
    ref.listenManual(creditsOrgIdProvider, (_, orgId) {
      if (orgId.isEmpty) return;
      // A cold-start payment link can arrive before session restoration.
      for (final sessionId in _pendingSessions.toList()) {
        unawaited(_verifySession(sessionId));
      }
    });
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (error) {
      AppLogger.w('Failed to read initial payment deep link', tag: _tag);
    }

    if (!mounted) return;

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleUri(uri)),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.w('Payment deep link stream error: $error', tag: _tag);
      },
    );
  }

  Future<void> _handleUri(Uri uri) async {
    final sessionId = CreditsPaymentDeepLinkParser.extractSessionId(
      uri,
      trustedWebHosts: trustedWebHosts(locator<AppConfig>()),
    );
    if (sessionId != null) await _verifySession(sessionId);
  }

  Future<void> _verifySession(String sessionId) async {
    if (!mounted ||
        _verifiedSessions.contains(sessionId) ||
        _verifyingSessions.contains(sessionId)) {
      return;
    }

    // The purchase was made for the workspace selected in the sidebar.
    final orgId = ref.read(creditsOrgIdProvider);
    if (orgId.isEmpty) {
      _pendingSessions.add(sessionId);
      return;
    }

    _pendingSessions.remove(sessionId);
    _verifyingSessions.add(sessionId);
    AppLogger.i('Verifying credit payment session', tag: _tag);
    final bool verified;
    try {
      verified = await ref
          .read(creditsNotifierProvider.notifier)
          .verifyPayment(sessionId: sessionId, orgId: orgId);
    } catch (error) {
      AppLogger.w('Failed to verify credit payment session', tag: _tag);
      return;
    } finally {
      // Failure leaves the session available for an explicit retry.
      _verifyingSessions.remove(sessionId);
    }

    if (!mounted) return;
    if (verified) _verifiedSessions.add(sessionId);

    // Mounted from `App`'s builder, above the Navigator: see the note in
    // AuthDeepLinkListener.
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return;

    if (verified) {
      AppToastService.showAtRoot(
        navigator,
        type: AppToastType.success,
        message: 'AI credits purchased successfully!',
      );
      if (GoRouter.of(
            navigator.context,
          ).routerDelegate.currentConfiguration.uri.path !=
          AppRouter.buyCredits) {
        navigator.context.go(AppRouter.buyCredits);
      }
      return;
    }

    final error = ref.read(creditsNotifierProvider).error;
    if (error != null) {
      AppToastService.showAtRoot(
        navigator,
        type: AppToastType.error,
        message: error,
      );
    }
  }

  @override
  void dispose() {
    unawaited(_linkSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
