import 'dart:async';

import 'package:zedu/core/core.dart';

/// Watches the accelerometer and, when the device is shaken, opens the
/// report-a-problem mail draft (see [reportContent]).
///
/// Inert on platforms without an accelerometer. [samples] and [onShake]
/// exist so tests can drive the listener without device sensors.
class ShakeToReportListener extends StatefulWidget {
  const ShakeToReportListener({
    super.key,
    required this.child,
    this.samples,
    this.onShake,
  });

  final Widget child;

  /// Overrides the accelerometer source (tests).
  final Stream<AccelSample>? samples;

  /// Overrides the shake response (tests).
  final void Function()? onShake;

  @override
  State<ShakeToReportListener> createState() => _ShakeToReportListenerState();
}

class _ShakeToReportListenerState extends State<ShakeToReportListener> {
  StreamSubscription<AccelSample>? _subscription;

  @override
  void initState() {
    super.initState();
    final samples = widget.samples ?? deviceAccelerometerSamples();
    _subscription = ShakeDetector().shakes(samples).listen((_) => _onShake());
  }

  void _onShake() {
    final onShake = widget.onShake;
    if (onShake != null) {
      onShake();
      return;
    }
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return;
    reportContent(
      context,
      subject: 'Report a problem',
      details: 'A shake opened this draft. Describe the problem you found:\n\n',
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
