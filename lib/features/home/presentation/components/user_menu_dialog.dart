import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Widest the profile menu card grows, so it does not crowd the workspace.
const double _maxCardWidth = 288;

/// Narrowest the card shrinks to on small desktop windows.
const double _minCardWidth = 240;

/// Gap between the sidebar rail and the card's left edge.
const double _railGap = 8;

/// Horizontal padding shared by the card's rows and menu items.
const double _cardHorizontalPadding = 12;

class UserMenuDialog extends ConsumerWidget {
  const UserMenuDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final authUser = ref.watch(authNotifierProvider).user;
    final balance = ref.watch(orgCreditBalanceProvider);
    final displayName = authUser?.fullname ?? 'AnonymousUser';
    final status = authUser?.status ?? UserStatus.empty;
    final orgSlug = authUser?.currentOrganisationSlug ?? '';
    final signOutTarget = orgSlug.isEmpty ? 'Zedu' : orgSlug;
    final isOnline = status.online;

    // Sit the card just outside the rail and keep it inside the window: it
    // grows to [_maxCardWidth] and shrinks on windows too narrow for that.
    final cardWidth =
        (MediaQuery.sizeOf(context).width -
                AppSidebarRail.width -
                _railGap -
                16)
            .clamp(_minCardWidth, _maxCardWidth)
            .toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.only(
        left: AppSidebarRail.width + _railGap,
        right: 16,
        bottom: 24,
      ),
      alignment: Alignment.bottomLeft,
      backgroundColor: colors.background,
      child: Container(
        key: const ValueKey('user_menu_card'),
        width: cardWidth,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Profile header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _cardHorizontalPadding,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Avatar with presence dot overlay
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: colors.sidebar,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _UserMenuAvatar(
                            avatarUrl: authUser?.avatarUrl ?? '',
                            displayName: displayName,
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: PresenceDot(online: isOnline, size: 12),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Presence label
                          Text(
                            isOnline ? 'Active' : 'Away',
                            style: TextStyle(
                              color: isOnline
                                  ? colors.presenceActive
                                  : colors.textHint,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$balance AI credits',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 0, color: colors.divider),
              const SizedBox(height: 8),

              // ── Custom status row ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _cardHorizontalPadding,
                ),
                child: InkWell(
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    Navigator.pop(context);
                    await showDialog<void>(
                      context: context,
                      builder: (_) => const SetStatusDialog(),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (status.hasCustomStatus)
                          Text(
                            status.emoji ?? '😶',
                            style: const TextStyle(fontSize: 18),
                          )
                        else
                          Icon(
                            Icons.sentiment_satisfied_alt_outlined,
                            color: colors.textHint,
                            size: 20,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            status.hasCustomStatus
                                ? (status.text ?? 'Status set')
                                : 'Update your status',
                            style: TextStyle(
                              color: status.hasCustomStatus
                                  ? colors.textPrimary
                                  : colors.textHint,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Clear status (only visible when status is set) ─────────────
              if (status.hasCustomStatus)
                _MenuItemButton(
                  icon: Icons.clear_all_outlined,
                  label: 'Clear status',
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(authNotifierProvider.notifier).clearStatus();
                  },
                ),

              // ── Set yourself as active / away toggle ──────────────────────
              _MenuItemButton(
                icon: isOnline
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                label: isOnline
                    ? 'Set yourself as away'
                    : 'Set yourself as active',
                iconColor: isOnline ? colors.presenceActive : colors.textHint,
                onTap: () async {
                  // Capture everything needed before the menu closes: once
                  // the dialog route is disposed, neither `context` nor `ref`
                  // may be touched again. The outcome carries its own error
                  // message, so nothing is re-read from the widget tree.
                  final overlay = Overlay.of(context, rootOverlay: true);
                  final notifier = ref.read(authNotifierProvider.notifier);
                  Navigator.pop(context);
                  final outcome = await notifier.toggleOnlineStatus();
                  switch (outcome) {
                    case PresenceFailed(:final message):
                      if (!overlay.mounted) return;
                      AppToastService.showWith(
                        overlay,
                        type: AppToastType.error,
                        message: message,
                      );
                    case PresenceConfirmed() || PresenceSkipped():
                      break;
                  }
                },
              ),

              // ── Pause notifications ────────────────────────────────────────
              _MenuItemButton(
                icon: Icons.notifications_off_outlined,
                label: 'Pause notifications',
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(notificationSettingsProvider.notifier)
                      .setDndMode(const Duration(hours: 1));
                },
              ),
              const SizedBox(height: 8),
              Divider(height: 0, color: colors.divider),
              const SizedBox(height: 8),

              // ── Settings shortcuts ─────────────────────────────────────────
              _MenuItemButton(
                icon: Icons.person_outline,
                label: 'Profile…',
                onTap: () {
                  Navigator.pop(context);
                  ref.read(personalProfilePanelProvider.notifier).state = true;
                },
              ),
              _MenuItemButton(
                icon: Icons.settings_outlined,
                label: 'Preferences…',
                onTap: () {
                  Navigator.pop(context);
                  if (context.mounted) context.go(AppRouter.profile);
                },
              ),
              _MenuItemButton(
                icon: Icons.shopping_cart_outlined,
                label: 'Buy AI credits',
                isHighlight: true,
                onTap: () {
                  Navigator.pop(context);
                  if (context.mounted) context.go(AppRouter.buyCredits);
                },
              ),
              const SizedBox(height: 8),
              Divider(height: 0, color: colors.divider),
              const SizedBox(height: 8),

              // ── Sign out ───────────────────────────────────────────────────
              _MenuItemButton(
                icon: Icons.logout_rounded,
                label: 'Sign out of $signOutTarget',
                isError: true,
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) context.go(AppRouter.login);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Internal helper widget ─────────────────────────────────────────────────────

class _MenuItemButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isHighlight;
  final bool isError;

  const _MenuItemButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.isHighlight = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final itemColor = isError
        ? colors.error
        : (isHighlight ? colors.accent : colors.textPrimary);
    final resolvedIconColor = iconColor ?? itemColor;

    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _cardHorizontalPadding,
          vertical: 8,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: resolvedIconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 13,
                  fontWeight: isHighlight || isError
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserMenuAvatar extends StatelessWidget {
  const _UserMenuAvatar({required this.avatarUrl, required this.displayName});

  final String avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl.trim();
    if (url.isEmpty) return _initials();

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _initials(),
    );
  }

  Widget _initials() {
    return Center(
      child: Text(
        _initialsFor(displayName),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  if (parts.isEmpty) return '?';
  return parts
      .map((part) => String.fromCharCode(part.runes.first).toUpperCase())
      .join();
}
