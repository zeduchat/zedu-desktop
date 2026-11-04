import 'dart:async';

import 'package:zedu/core/core.dart';

enum AppToastType { success, error, info }

class AppToastService {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required AppToastType type,
    required String message,
  }) {
    _current?.remove();
    _current = null;

    final overlay = Overlay.of(context);
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
              entry.remove();
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
  bool _hovered = false;

  static const _dismissDelay = Duration(seconds: 4);

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
    _cancelDismissTimer();
    _dismissTimer = Timer(_dismissDelay, _dismiss);
  }

  void _cancelDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  void _onHoverEnter() {
    if (_hovered) return;
    setState(() => _hovered = true);
    _cancelDismissTimer();
  }

  void _onHoverExit() {
    if (!_hovered) return;
    setState(() => _hovered = false);
    _startDismissTimer();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _cancelDismissTimer();
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
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
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
                              message: 'Dismiss',
                              child: Semantics(
                                button: true,
                                label: 'Dismiss',
                                child: InkWell(
                                  onTap: _dismiss,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16 * s,
                                      color: context.colors.textHint,
                                    ),
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
