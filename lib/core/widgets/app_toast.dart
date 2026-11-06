import 'dart:async';

import 'package:zedu/core/core.dart';

enum AppToastType { success, error, info }

class AppToastService {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required AppToastType type,
    required String message,
  }) => showWith(
    Overlay.of(context, rootOverlay: true),
    type: type,
    message: message,
  );

  /// Shows the toast on an [OverlayState] captured ahead of an async gap, so
  /// callers can still surface feedback after their own widget tree is gone.
  static void showWith(
    OverlayState overlay, {
    required AppToastType type,
    required String message,
  }) {
    _show(overlay, type: type, message: message);
  }

  /// For callers mounted above the Navigator, where [BuildContext] has no
  /// Overlay ancestor yet, such as the deep-link listeners in `App`'s builder.
  static void showAtRoot(
    NavigatorState navigator, {
    required AppToastType type,
    required String message,
  }) {
    final overlay = navigator.overlay;
    if (overlay == null) return;
    _show(overlay, type: type, message: message);
  }

  static void _show(
    OverlayState overlay, {
    required AppToastType type,
    required String message,
  }) {
    final previous = _current;
    if (previous != null && previous.mounted) previous.remove();
    _current = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final scale = mq.size.width >= SizeConfig.baseWidth
            ? 1.0
            : mq.size.width / SizeConfig.baseWidth;
        return Positioned(
          top: mq.padding.top + 24 * scale,
          right: 24 * scale,
          child: _AppToastWidget(
            type: type,
            message: message,
            scale: scale,
            onDismiss: () {
              // The close button and the timer can both end the same toast,
              // and a newer toast may already have removed this one.
              if (entry.mounted) entry.remove();
              if (_current == entry) _current = null;
            },
          ),
        );
      },
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _AppToastWidget extends StatefulWidget {
  const _AppToastWidget({
    required this.type,
    required this.message,
    required this.scale,
    required this.onDismiss,
  });

  final AppToastType type;
  final String message;
  final double scale;
  final VoidCallback onDismiss;

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _startDismissTimer();
  }

  void _startDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _pauseDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  bool _dismissing = false;

  Future<void> _dismiss() async {
    if (!mounted || _dismissing) return;
    _dismissing = true;
    _pauseDismissTimer();
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final colors = context.colors;

    final (accentColor, bgColor, icon, title) = switch (widget.type) {
      AppToastType.success => (
        colors.success,
        colors.successBg,
        Icons.check_circle_outline_rounded,
        'Success',
      ),
      AppToastType.error => (
        colors.error,
        colors.errorBg,
        Icons.error_outline_rounded,
        'Error',
      ),
      AppToastType.info => (
        colors.primary,
        colors.primaryBg,
        Icons.info_outline_rounded,
        'Info',
      ),
    };

    return MouseRegion(
      onEnter: (_) => _pauseDismissTimer(),
      onExit: (_) => _startDismissTimer(),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 340 * s,
              constraints: BoxConstraints(minHeight: 64 * s),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8 * s),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * s),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 4 * s, color: accentColor),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14 * s,
                            vertical: 12 * s,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, color: accentColor, size: 20 * s),
                              SizedBox(width: 10 * s),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title,
                                      style: context.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: accentColor,
                                          ),
                                    ),
                                    SizedBox(height: 3 * s),
                                    Text(
                                      widget.message,
                                      style: context.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: context.colors.textPrimary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8 * s),
                              Tooltip(
                                message: 'Dismiss notification',
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: _dismiss,
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16 * s,
                                      color: context.colors.textHint,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
