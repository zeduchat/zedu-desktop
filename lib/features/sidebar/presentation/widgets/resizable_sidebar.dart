import 'package:flutter/material.dart';

class ResizableSidebar extends StatefulWidget {
  const ResizableSidebar({
    super.key,
    required this.child,
    this.initialWidth = 320,
    this.minWidth = defaultMinWidth,
    this.maxWidth = defaultMaxWidth,
  });

  static const double defaultMinWidth = 220;
  static const double defaultMaxWidth = 420;

  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;

  @override
  State<ResizableSidebar> createState() => _ResizableSidebarState();
}

class _ResizableSidebarState extends State<ResizableSidebar> {
  late double _width;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth
        .clamp(widget.minWidth, widget.maxWidth)
        .toDouble();
  }

  @override
  void didUpdateWidget(covariant ResizableSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minWidth != widget.minWidth ||
        oldWidget.maxWidth != widget.maxWidth) {
      _width = _width.clamp(widget.minWidth, widget.maxWidth).toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('resizable-sidebar'),
      width: _width,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 10,
            child: GestureDetector(
              key: const ValueKey('resizable-sidebar-handle'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _width = (_width + details.delta.dx)
                      .clamp(widget.minWidth, widget.maxWidth)
                      .toDouble();
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(right: 4),
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
