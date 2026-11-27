import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Settings > Personal > Account, laid out like Zedu web's Account page: a
/// profile card with Change photo and Edit profile, then a Personal details
/// list where each editable row has its own action. The Desktop-only launch
/// at login switch and the delete account card follow.
class AccountSection extends StatelessWidget {
  const AccountSection({
    super.key,
    required this.account,
    required this.isSaving,
    required this.onSave,
    required this.onDelete,
    this.status,
    this.onEditStatus,
  });

  final ProfileAccount account;
  final bool isSaving;

  /// Saves the Edit profile dialog: the edited fields and the photo change.
  final EditProfileSave onSave;
  final Future<void> Function() onDelete;

  /// The signed-in user's custom status, shown in the Status row.
  final UserStatus? status;

  /// Opens the set status dialog. The Status row has no action without it.
  final VoidCallback? onEditStatus;

  static const double _rowLabelWidth = 160;

  String get _displayName {
    final display = account.displayName.trim();
    return display.isNotEmpty ? display : account.name.trim();
  }

  String get _username => account.username.trim().replaceAll(' ', '_');

  /// The handle under the name: the saved username, or one made from the
  /// name when the account has none yet.
  String get _handle => _username.isNotEmpty
      ? _username
      : account.name.replaceAll(' ', '').toLowerCase();

  void _openEditor(BuildContext context) =>
      showEditProfileDialog(context, account, onSave);

  String _statusText(UserStatus status) => [
    status.emoji,
    status.text,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = status;
    final customStatus = current != null && current.hasCustomStatus
        ? current
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(
          title: 'Account',
          subtitle: 'Manage how you appear to others and your sign-in details.',
        ),
        const SizedBox(height: 24),
        _AccountCard(
          padding: const EdgeInsets.all(24),
          child: _ProfileHeader(
            displayName: _displayName,
            username: _handle,
            initials: account.initials,
            avatarUrl: account.avatarUrl,
            onChangePhoto: () => _openEditor(context),
            onEditProfile: () => _openEditor(context),
          ),
        ),
        const SizedBox(height: 16),
        _AccountCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: Text(
                  'Personal details',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              ..._divided(colors, [
                _DetailRow(
                  label: 'Display name',
                  labelWidth: _rowLabelWidth,
                  value: _displayName,
                  actionLabel: 'Edit',
                  actionTooltip: 'Edit display name',
                  onAction: () => _openEditor(context),
                ),
                if (_username.isNotEmpty)
                  _DetailRow(
                    label: 'Username',
                    labelWidth: _rowLabelWidth,
                    value: '@$_username',
                  ),
                _DetailRow(
                  label: 'Title',
                  labelWidth: _rowLabelWidth,
                  value: account.title,
                  actionLabel: 'Edit',
                  actionTooltip: 'Edit title',
                  onAction: () => _openEditor(context),
                ),
                _DetailRow(
                  label: 'Email address',
                  labelWidth: _rowLabelWidth,
                  value: account.email,
                ),
                _DetailRow(
                  label: 'Phone number',
                  labelWidth: _rowLabelWidth,
                  value: account.phoneNumber,
                  actionLabel: 'Edit',
                  actionTooltip: 'Edit phone number',
                  onAction: () => _openEditor(context),
                ),
                _DetailRow(
                  label: 'Status',
                  labelWidth: _rowLabelWidth,
                  value: customStatus == null ? '' : _statusText(customStatus),
                  emptyText: 'No status set',
                  actionLabel: customStatus == null
                      ? 'Set a status'
                      : 'Update status',
                  onAction: onEditStatus,
                ),
                _DetailRow(
                  label: 'Time zone',
                  labelWidth: _rowLabelWidth,
                  value: profileTimezoneLabel(account.timezone),
                  actionLabel: 'Edit',
                  actionTooltip: 'Edit time zone',
                  onAction: () => _openEditor(context),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const LaunchAtLoginTile(),
        const SizedBox(height: 16),
        _AccountCard(
          borderColor: colors.error.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(24),
          child: _DeleteAccountRow(
            isSaving: isSaving,
            onDelete: () => _confirmDelete(context, onDelete),
          ),
        ),
      ],
    );
  }

  /// [rows] with a divider above each one.
  List<Widget> _divided(AppPalette colors, List<Widget> rows) => [
    for (final row in rows) ...[
      Divider(height: 1, thickness: 1, color: colors.divider),
      row,
    ],
  ];

  Future<void> _confirmDelete(
    BuildContext context,
    Future<void> Function() onConfirm,
  ) => showProfileConfirmDialog(
    context,
    title: 'Delete account?',
    message:
        'This action cannot be undone. Your account information will be removed.',
    confirmLabel: 'Delete account',
    onConfirm: onConfirm,
    destructive: true,
  );
}

/// A rounded card with a light border, like the cards on Zedu web.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? context.colors.divider),
      ),
      child: child,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.username,
    required this.initials,
    required this.avatarUrl,
    required this.onChangePhoto,
    required this.onEditProfile,
  });

  final String displayName;
  final String username;
  final String initials;
  final String? avatarUrl;
  final VoidCallback onChangePhoto;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName.isEmpty ? 'Not set' : displayName,
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        if (username.isNotEmpty)
          Text(
            '@$username',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
      ],
    );
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          key: const ValueKey('account_change_photo'),
          onPressed: onChangePhoto,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            fixedSize: const Size.fromHeight(44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.borderOutline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text('Change photo'),
        ),
        FilledButton.icon(
          key: const ValueKey('account_edit_profile'),
          onPressed: onEditProfile,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            fixedSize: const Size.fromHeight(44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit profile'),
        ),
      ],
    );
    final avatar = _Avatar(initials: initials, avatarUrl: avatarUrl);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow windows put the buttons under the name, as web does on small
        // screens, so nothing overflows.
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  avatar,
                  const SizedBox(width: 16),
                  Expanded(child: identity),
                ],
              ),
              const SizedBox(height: 16),
              buttons,
            ],
          );
        }
        return Row(
          children: [
            avatar,
            const SizedBox(width: 16),
            Expanded(child: identity),
            const SizedBox(width: 16),
            buttons,
          ],
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.avatarUrl});

  final String initials;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: context.colors.primary,
        ),
      ),
    );
    return Container(
      key: const ValueKey('account_avatar'),
      width: 88,
      height: 88,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.primaryBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              // A broken link still shows who this account is.
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// One Personal details row: label, value ([emptyText] when empty) and an
/// optional action link on the right.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.labelWidth,
    required this.value,
    this.emptyText = 'Not set',
    this.actionLabel,
    this.actionTooltip,
    this.onAction,
  });

  final String label;
  final double labelWidth;
  final String value;
  final String emptyText;
  final String? actionLabel;
  final String? actionTooltip;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trimmed = value.trim();
    final labelText = Text(
      label,
      style: context.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
    );
    final valueText = Text(
      trimmed.isEmpty ? emptyText : trimmed,
      style: context.textTheme.bodyMedium?.copyWith(
        color: trimmed.isEmpty ? colors.textHint : colors.textPrimary,
      ),
    );
    final actionText = actionLabel;
    final onTap = onAction;
    final Widget? action = actionText != null && onTap != null
        ? Tooltip(
            message: actionTooltip ?? actionText,
            child: TextButton(
              key: ValueKey('account_action_$label'),
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                actionText,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On narrow windows the label sits above the value, as on web.
          final narrow = constraints.maxWidth < 440;
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              children: [
                if (narrow)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        labelText,
                        const SizedBox(height: 2),
                        valueText,
                      ],
                    ),
                  )
                else ...[
                  SizedBox(width: labelWidth, child: labelText),
                  Expanded(child: valueText),
                ],
                ?action,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeleteAccountRow extends StatelessWidget {
  const _DeleteAccountRow({required this.isSaving, required this.onDelete});

  final bool isSaving;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Delete account',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.error,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your account information will be removed and you will be signed '
          'out. This cannot be undone.',
          style: context.textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
    final button = AppButton.outlined(
      label: 'Delete my account',
      expand: false,
      height: 44,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.error,
        side: BorderSide(color: colors.error),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      loading: isSaving,
      onPressed: onDelete,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 16), button],
          );
        }
        return Row(
          children: [
            Expanded(child: text),
            const SizedBox(width: 16),
            button,
          ],
        );
      },
    );
  }
}
