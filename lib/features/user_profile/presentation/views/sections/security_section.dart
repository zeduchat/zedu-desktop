import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SecuritySection extends StatelessWidget {
  const SecuritySection({
    super.key,
    required this.sessions,
    required this.isSaving,
    required this.onChangePassword,
  });

  final List<SecuritySession> sessions;
  final bool isSaving;
  final Future<Result<void>> Function({
    required String currentPassword,
    required String newPassword,
  })
  onChangePassword;

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
        _SessionsTable(sessions: sessions),
      ],
    );
  }
}

class _SessionsTable extends StatelessWidget {
  const _SessionsTable({required this.sessions});

  final List<SecuritySession> sessions;

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
            headingRowColor: WidgetStateProperty.all(const Color(0xFFFAFAFA)),
            columns: const [
              DataColumn(label: Text('Device')),
              DataColumn(label: Text('Location')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Last active')),
              DataColumn(label: Text('Status')),
            ],
            rows: sessions.map((session) {
              return DataRow(
                cells: [
                  DataCell(Text(session.device)),
                  DataCell(Text(session.location)),
                  DataCell(Text(session.date)),
                  DataCell(Text(session.lastActive)),
                  DataCell(ProfileStatusPill(status: session.status)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
