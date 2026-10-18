import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class PersonalProfilePanel extends ConsumerWidget {
  const PersonalProfilePanel({super.key, this.width = 360});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profileState = ref.watch(userProfileNotifierProvider);
    final account = profileState.account ?? ProfileAccount.empty();
    final menuState = ref.watch(userMenuStateProvider);

    final displayName = account.displayName.isNotEmpty
        ? account.displayName
        : account.name;
    final roleTitle = account.title.isNotEmpty ? account.title : 'Member';

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
        border: Border(left: BorderSide(color: colors.divider)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Text(
                  'Profile',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ref.read(personalProfilePanelProvider.notifier).state =
                        false;
                  },
                  icon: Icon(Icons.close, size: 18, color: colors.textHint),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(Icons.person, size: 80, color: colors.accent),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name and edit button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _openEditDialog(context, ref, account),
                        borderRadius: BorderRadius.circular(4),
                        child: Text(
                          'Edit',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Role/Title
                  Text(
                    roleTitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        menuState.notificationsPaused
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_none,
                        size: 14,
                        color: colors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        menuState.isAway ? 'Away' : 'Active',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.textHint,
                        ),
                      ),
                      if (menuState.notificationsPaused) ...[
                        Text(
                          ', Notifications snoozed',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Time icon
                  Icon(Icons.access_time, size: 14, color: colors.textHint),
                  const SizedBox(height: 16),

                  // Action buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionChip(
                        icon: Icons.star_outline,
                        label: '',
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.notifications_off_outlined,
                        label: 'Mute',
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.visibility_off_outlined,
                        label: 'Hide',
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.description_outlined,
                        label: 'View Files',
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.copy_outlined,
                        label: '',
                        colors: colors,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Contact Information section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Contact Information',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: account.phoneNumber.isNotEmpty
                        ? account.phoneNumber
                        : 'Not provided',
                    colors: colors,
                    context: context,
                  ),
                  const SizedBox(height: 8),

                  // Email
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: account.email,
                    colors: colors,
                    context: context,
                    isLink: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    ProfileAccount account,
  ) {
    showEditProfileDialog(context, account, (updated) {
      ref.read(userProfileNotifierProvider.notifier).updateAccount(updated);
    });
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colors.textSecondary),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.colors,
    required this.context,
    this.isLink = false,
  });

  final IconData icon;
  final String label;
  final AppPalette colors;
  final BuildContext context;
  final bool isLink;

  @override
  Widget build(BuildContext buildContext) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textHint),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: buildContext.textTheme.bodySmall?.copyWith(
              color: isLink ? colors.primary : colors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(4),
          child: Icon(Icons.copy_outlined, size: 14, color: colors.textHint),
        ),
      ],
    );
  }
}
