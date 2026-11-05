import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SecuritySection extends StatelessWidget {
  const SecuritySection({
    super.key,
    required this.sessions,
    required this.isSaving,
    required this.onChangePassword,
    this.onRevokeSession,
  });

  final List<SecuritySession> sessions;
  final bool isSaving;
  final Future<Result<void>> Function({
    required String currentPassword,
    required String newPassword,
  }) onChangePassword;
  final Future<Result<void>> Function(String sessionId)? onRevokeSession;

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
          onRevoke: onRevokeSession,
        ),
      ],
    );
  }
}

class _SessionsTable extends StatelessWidget {
  const _SessionsTable({
    required this.sessions,
    this.onRevoke,
  });

  final List<SecuritySession> sessions;
  final Future<Result<void>> Function(String sessionId)? onRevoke;

  void _confirmRevoke(BuildContext context, SecuritySession session) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke Session'),
        content: Text(
          'Are you sure you want to sign out and revoke the session on ${session.device} (${session.location})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('confirm-revoke-button'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (onRevoke != null) {
                onRevoke!(session.id.isNotEmpty ? session.id : session.device);
              }
            },
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

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

    final hasRevokeAction = onRevoke != null;

    return ProfileCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 800),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFFAFAFA)),
            columns: [
              const DataColumn(label: Text('Device')),
              const DataColumn(label: Text('Location')),
              const DataColumn(label: Text('Date')),
              const DataColumn(label: Text('Last active')),
              const DataColumn(label: Text('Status')),
              if (hasRevokeAction) const DataColumn(label: Text('Action')),
            ],
            rows: sessions.map((session) {
              return DataRow(
                cells: [
                  DataCell(Text(session.device)),
                  DataCell(Text(session.location)),
                  DataCell(Text(session.date)),
                  DataCell(Text(session.lastActive)),
                  DataCell(ProfileStatusPill(status: session.status)),
                  if (hasRevokeAction)
                    DataCell(
                      TextButton(
                        key: ValueKey('revoke-${session.id.isNotEmpty ? session.id : session.device}'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _confirmRevoke(context, session),
                        child: const Text('Revoke'),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
