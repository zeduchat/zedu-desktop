import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SecuritySection extends StatelessWidget {
  const SecuritySection({
    super.key,
    required this.sessions,
    required this.isSaving,
    required this.onChangePassword,
    this.onRevoke,
  });

  final List<SecuritySession> sessions;
  final bool isSaving;
  final Future<Result<void>> Function({
    required String currentPassword,
    required String newPassword,
  })
  onChangePassword;

  /// Signs out a session by its id. Without it the table has no actions.
  final Future<void> Function(String sessionId)? onRevoke;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          title: 'Your Account Security',
          subtitle: 'Keeping your data secure by staying in-the-know',
          trailing: AppButton.outlined(
            label: 'Change password',
            expand: false,
            height: 44,
            loading: isSaving,
            onPressed: () =>
                showChangePasswordDialog(context, onChangePassword),
          ),
        ),
        const SizedBox(height: 28),
        _SessionsTable(
          sessions: sessions,
          isSaving: isSaving,
          onRevoke: onRevoke,
        ),
      ],
    );
  }
}

class _SessionsTable extends StatelessWidget {
  const _SessionsTable({
    required this.sessions,
    required this.isSaving,
    required this.onRevoke,
  });

  final List<SecuritySession> sessions;
  final bool isSaving;
  final Future<void> Function(String sessionId)? onRevoke;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const ProfileCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Text('No active sessions found')),
        ),
      );
    }

    return ProfileCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 800),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(context.colors.background),
            columns: [
              const DataColumn(label: Text('Device')),
              const DataColumn(label: Text('Location')),
              const DataColumn(label: Text('Date')),
              const DataColumn(label: Text('Last active')),
              const DataColumn(label: Text('Status')),
              if (onRevoke != null) const DataColumn(label: Text('Action')),
            ],
            rows: sessions.map((session) {
              return DataRow(
                cells: [
                  DataCell(Text(session.device)),
                  DataCell(Text(session.location)),
                  DataCell(Text(session.date)),
                  DataCell(Text(session.lastActive)),
                  DataCell(ProfileStatusPill(status: session.status)),
                  if (onRevoke case final revoke?)
                    DataCell(
                      session.canRevoke
                          ? TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: context.colors.error,
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () => _confirmRevoke(
                                      context,
                                      session,
                                      revoke,
                                    ),
                              child: const Text('Sign out'),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    SecuritySession session,
    Future<void> Function(String sessionId) revoke,
  ) => showProfileConfirmDialog(
    context,
    title: 'Sign out this session?',
    message:
        'The device using this session will be signed out of Zedu. '
        'If it is this computer, you will be signed out here too.',
    confirmLabel: 'Sign out',
    onConfirm: () => revoke(session.id),
    destructive: true,
  );
}
