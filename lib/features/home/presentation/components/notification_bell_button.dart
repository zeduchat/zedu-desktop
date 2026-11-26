import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The notifications bell in the sidebar rail.
///
/// Hovering it for [hoverDelay] shows [NotificationPreviewPopover] with the
/// most recent unread DMs. The popover stays open while the pointer moves
/// onto it and closes [hoverDelay] after the pointer leaves both. Clicking the
/// bell opens the full [NotificationsDialog]; Escape closes the preview.
class NotificationBellButton extends ConsumerStatefulWidget {
  const NotificationBellButton({
    super.key,
    this.hasUnread = false,
    this.hoverDelay = const Duration(milliseconds: 180),
  });

  final bool hasUnread;
  final Duration hoverDelay;

  @override
  ConsumerState<NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState
    extends ConsumerState<NotificationBellButton> {
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();

  Timer? _showTimer;
  Timer? _hideTimer;

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _cancelTimers() {
    _showTimer?.cancel();
    _showTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _show() {
    if (!mounted || _overlayController.isShowing) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    setState(_overlayController.show);
  }

  void _hide() {
    _cancelTimers();
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (!mounted || !_overlayController.isShowing) return;
    setState(_overlayController.hide);
  }

  /// Escape closes the preview wherever keyboard focus is, since hovering
  /// does not focus the bell.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        !_overlayController.isShowing) {
      return false;
    }
    _hide();
    return true;
  }

  void _onBellEnter() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (_overlayController.isShowing) return;
    _showTimer?.cancel();
    _showTimer = Timer(widget.hoverDelay, _show);
  }

  void _onPointerLeave() {
    _showTimer?.cancel();
    _showTimer = null;
    if (!_overlayController.isShowing) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.hoverDelay, _hide);
  }

  void _onPopoverEnter() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _openPanel() {
    _hide();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => const NotificationsDialog(),
    );
  }

  void _openConversation(DmConversation conversation) {
    final router = GoRouter.maybeOf(context);
    _hide();
    ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.dms);
    ref.read(selectedDmProvider.notifier).select(conversation);
    if (router != null &&
        router.routerDelegate.currentConfiguration.uri.path != AppRouter.home) {
      router.go(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isOpen = _overlayController.isShowing;

    return Semantics(
      button: true,
      label: 'Notifications',
      expanded: isOpen,
      child: MouseRegion(
        onEnter: (_) => _onBellEnter(),
        onExit: (_) => _onPointerLeave(),
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (context) => Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.bottomLeft,
              offset: const Offset(12, 0),
              child: MouseRegion(
                onEnter: (_) => _onPopoverEnter(),
                onExit: (_) => _onPointerLeave(),
                child: NotificationPreviewPopover(
                  onOpenConversation: _openConversation,
                  onViewAll: _openPanel,
                ),
              ),
            ),
          ),
          child: CompositedTransformTarget(
            link: _layerLink,
            child: InkWell(
              onTap: _openPanel,
              borderRadius: BorderRadius.circular(7),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isOpen
                            ? colors.primary.withValues(alpha: 0.95)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.notifications_none_outlined,
                        color: colors.onPrimary,
                        size: 20,
                      ),
                    ),
                    if (widget.hasUnread)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          key: const Key('notification-unread-indicator'),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.error,
                            shape: BoxShape.circle,
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
    );
  }
}
