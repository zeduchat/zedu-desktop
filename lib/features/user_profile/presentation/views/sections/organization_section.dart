import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class OrganizationSection extends StatefulWidget {
  const OrganizationSection({
    super.key,
    required this.organization,
    required this.onSave,
    required this.onDelete,
    required this.onLeave,
  });

  final OrganizationProfile organization;
  final ValueChanged<OrganizationProfile> onSave;
  final Future<void> Function() onDelete;
  final Future<void> Function() onLeave;

  @override
  State<OrganizationSection> createState() => _OrganizationSectionState();
}

/// The destructive action that is running, so only the button the user pressed
/// shows a spinner.
enum _OrganizationAction { leave, delete }

class _OrganizationSectionState extends State<OrganizationSection> {
  _OrganizationAction? _pending;

  bool get _isBusy => _pending != null;

  /// Runs [onConfirm] while only [action]'s button shows a spinner. A second
  /// press while one is running is ignored.
  Future<void> _run(
    _OrganizationAction action,
    Future<void> Function() onConfirm,
  ) async {
    if (_isBusy) return;
    setState(() => _pending = action);
    try {
      await onConfirm();
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organization = widget.organization;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(
          title: 'Your Organization Information',
          subtitle: 'Manage your organization details.',
        ),
        const SizedBox(height: 28),
        ProfileCard(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 480,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OrganizationAvatar(initials: organization.initials),
                    const SizedBox(height: 24),
                    const ProfileFieldLabel('Name'),
                    const SizedBox(height: 4),
                    Text(
                      organization.name,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const ProfileFieldLabel('Nature of business'),
                    const SizedBox(height: 4),
                    Text(
                      organization.natureOfBusiness,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const ProfileFieldLabel('Country'),
                    const SizedBox(height: 4),
                    Text(
                      organization.country,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: SquareIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit organization',
                    onTap: () => showEditOrganizationDialog(
                      context,
                      organization,
                      widget.onSave,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        // Wraps so both buttons stay visible in a narrow window.
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            AppButton.outlined(
              label: 'Sign out of workspace',
              expand: false,
              height: 44,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textPrimary,
                side: BorderSide(color: context.colors.divider),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              loading: _pending == _OrganizationAction.leave,
              onPressed: () => _confirmLeave(context),
            ),
            AppButton.outlined(
              label: 'Delete organization',
              expand: false,
              height: 44,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.error,
                side: BorderSide(color: context.colors.error),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              loading: _pending == _OrganizationAction.delete,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmLeave(BuildContext context) => showProfileConfirmDialog(
    context,
    title: 'Sign out of workspace?',
    message:
        'This will securely sign you out and remove your access from this workspace. You will need to be re-invited to join again.',
    confirmLabel: 'Sign out',
    onConfirm: () => _run(_OrganizationAction.leave, widget.onLeave),
    destructive: true,
  );

  Future<void> _confirmDelete(BuildContext context) => showProfileConfirmDialog(
    context,
    title: 'Delete organization?',
    message:
        'This will remove the organization and its related workspace data.',
    confirmLabel: 'Delete organization',
    onConfirm: () => _run(_OrganizationAction.delete, widget.onDelete),
    destructive: true,
  );
}

class _OrganizationAvatar extends StatelessWidget {
  const _OrganizationAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: context.colors.primaryBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            color: context.colors.sidebar,
          ),
        ),
      ),
    );
  }
}
