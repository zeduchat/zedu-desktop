import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class AccountSection extends StatelessWidget {
  const AccountSection({
    super.key,
    required this.account,
    required this.isSaving,
    required this.onSave,
    required this.onDelete,
  });

  final ProfileAccount account;
  final bool isSaving;
  final ValueChanged<ProfileAccount> onSave;
  final Future<void> Function() onDelete;

  String get _handle {
    final username = account.username.trim();
    if (username.isNotEmpty) return '@$username';
    return '@${account.name.replaceAll(' ', '').toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(
          title: 'Your Account Information',
          subtitle: 'Manage your account data with ease.',
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _AvatarBlock(
                      initials: account.initials,
                      avatarUrl: account.avatarUrl,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: SquareIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit account',
                        onTap: () =>
                            _showAccountDialog(context, account, onSave),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const ProfileFieldLabel('Name'),
                const SizedBox(height: 4),
                Text(
                  account.name,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _handle,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 48),
            Expanded(
              child: ProfileCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProfileFieldLabel('Email Address'),
                    const SizedBox(height: 8),
                    Text(account.email, style: context.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        AppButton.outlined(
          label: 'Delete my account',
          expand: false,
          height: 44,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFEF4444)),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          loading: isSaving,
          onPressed: () => _confirmDelete(context, onDelete),
        ),
      ],
    );
  }

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

  void _showAccountDialog(
    BuildContext context,
    ProfileAccount account,
    ValueChanged<ProfileAccount> onSave,
  ) => showEditAccountDialog(context, account, onSave);
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({required this.initials, required this.avatarUrl});

  final String initials;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    final fallback = Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0B7A73),
        ),
      ),
    );
    return Container(
      width: 160,
      height: 144,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE9FBFA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              // A broken link still shows who this account is.
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
