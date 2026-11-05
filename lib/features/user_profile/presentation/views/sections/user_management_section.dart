import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

enum _UserManagementTab { members, invites }

/// `Nov 3, 2026` in local time for a server timestamp; anything else, such as
/// `Pending`, stays as it is.
String _formatDateJoined(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : formatFileDate(date.toLocal());
}

class UserManagementSection extends StatefulWidget {
  const UserManagementSection({
    super.key,
    required this.members,
    required this.isSaving,
    required this.onInvite,
    required this.onUpdate,
    required this.onRemove,
    this.invites,
  });

  final List<TeamMember> members;
  final bool isSaving;
  final Future<void> Function({required String email, required String role})
  onInvite;
  final ValueChanged<TeamMember> onUpdate;
  final ValueChanged<String> onRemove;
  final List<TeamMember>? invites;

  @override
  State<UserManagementSection> createState() => _UserManagementSectionState();
}

class _UserManagementSectionState extends State<UserManagementSection> {
  final _searchController = TextEditingController();
  String _roleFilter = 'All Roles';
  int _currentPage = 1;
  static const int _pageSize = 10;
  _UserManagementTab _currentTab = _UserManagementTab.members;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final hasActiveFilter = query.isNotEmpty || _roleFilter != 'All Roles';
    final filtered = widget.members.where((member) {
      final matchesQuery =
          query.isEmpty ||
          member.email.toLowerCase().contains(query) ||
          (member.name?.toLowerCase().contains(query) ?? false);
      final matchesRole =
          _roleFilter == 'All Roles' || member.role == _roleFilter;
      return matchesQuery && matchesRole;
    }).toList();

    final totalPages = (filtered.length / _pageSize).ceil();
    final currentPage = totalPages == 0 ? 1 : _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final paginatedMembers = filtered.skip(startIndex).take(_pageSize).toList();
    final invitesList =
        widget.invites ??
        widget.members
            .where((m) => m.status == TeamMemberStatus.pending)
            .toList();
    // The selected role stays listed after its last member is removed, since a
    // dropdown can't hold a value it has no item for.
    final roleOptions = {
      for (final member in widget.members)
        if (member.role.isNotEmpty) member.role,
      if (_roleFilter != 'All Roles') _roleFilter,
    }.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          title: 'Your Team',
          subtitle: 'Manage all members of your team.',
          trailing: AppButton(
            label: 'Invite People',
            expand: false,
            height: 44,
            loading: widget.isSaving,
            onPressed: () => _showInviteDialog(context, widget.onInvite),
          ),
        ),
        const SizedBox(height: 34),
        Row(
          children: [
            _TabLabel(
              label: 'Members',
              count: widget.members.length,
              active: _currentTab == _UserManagementTab.members,
              onTap: () {
                if (_currentTab != _UserManagementTab.members) {
                  setState(() {
                    _currentTab = _UserManagementTab.members;
                    _currentPage = 1;
                  });
                }
              },
            ),
            const SizedBox(width: 32),
            _TabLabel(
              label: 'Invites',
              count: invitesList.length,
              active: _currentTab == _UserManagementTab.invites,
              onTap: () {
                if (_currentTab != _UserManagementTab.invites) {
                  setState(() {
                    _currentTab = _UserManagementTab.invites;
                    _currentPage = 1;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_currentTab == _UserManagementTab.members)
          ProfileCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {
                            _currentPage = 1;
                          }),
                          decoration: InputDecoration(
                            hintText: 'Search by name or email',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _roleFilter,
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(
                            value: 'All Roles',
                            child: Text('All Roles'),
                          ),
                          for (final role in roleOptions)
                            DropdownMenuItem(value: role, child: Text(role)),
                        ],
                        onChanged: (value) => setState(() {
                          _roleFilter = value ?? 'All Roles';
                          _currentPage = 1;
                        }),
                      ),
                    ],
                  ),
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 48,
                      horizontal: 24,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: context.colors.divider,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              hasActiveFilter
                                  ? Icons.search_off_rounded
                                  : Icons.people_outline_rounded,
                              size: 28,
                              color: context.colors.textHint,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            hasActiveFilter
                                ? 'No members match your search.'
                                : 'No members found.',
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasActiveFilter
                                ? 'Try adjusting your search terms or role filters.'
                                : 'Invite people to your team to start collaborating.',
                            textAlign: TextAlign.center,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 880),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFFAFAFA),
                        ),
                        columns: const [
                          DataColumn(label: Text('Email Address')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Date Joined')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: paginatedMembers.map((member) {
                          return DataRow(
                            cells: [
                              DataCell(_MemberIdentity(email: member.email)),
                              DataCell(Text(member.role)),
                              DataCell(
                                Text(_formatDateJoined(member.dateJoined)),
                              ),
                              DataCell(
                                ProfileStatusPill(status: member.status.name),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SquareIconButton(
                                      icon: Icons.edit_outlined,
                                      tooltip: 'Edit member',
                                      size: 28,
                                      onTap: () => _showMemberDialog(
                                        context,
                                        member,
                                        widget.onUpdate,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SquareIconButton(
                                      icon: Icons.delete_outline,
                                      tooltip: 'Remove member',
                                      size: 28,
                                      onTap: () => _confirmRemove(
                                        context,
                                        member.email,
                                        () async => widget.onRemove(member.id),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                if (totalPages > 1) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        AppButton.outlined(
                          label: 'Previous',
                          expand: false,
                          height: 36,
                          disabled: currentPage <= 1,
                          onPressed: currentPage > 1
                              ? () => setState(
                                  () => _currentPage = currentPage - 1,
                                )
                              : null,
                        ),
                        const Spacer(),
                        Text(
                          '$currentPage',
                          key: const Key('user_management_page_number'),
                          style: context.textTheme.bodySmall,
                        ),
                        const Spacer(),
                        AppButton.outlined(
                          label: 'Next',
                          expand: false,
                          height: 36,
                          disabled: currentPage >= totalPages,
                          onPressed: currentPage < totalPages
                              ? () => setState(
                                  () => _currentPage = currentPage + 1,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          ProfileCard(
            padding: EdgeInsets.zero,
            child: invitesList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 48,
                      horizontal: 24,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: context.colors.divider,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mail_outline_rounded,
                              size: 28,
                              color: context.colors.textHint,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending invitations',
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'When you invite teammates, their pending invites will show up here.',
                            textAlign: TextAlign.center,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 880),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFFAFAFA),
                        ),
                        columns: const [
                          DataColumn(label: Text('Email Address')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Date Invited')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: invitesList.map((invite) {
                          return DataRow(
                            cells: [
                              DataCell(_MemberIdentity(email: invite.email)),
                              DataCell(Text(invite.role)),
                              DataCell(
                                Text(_formatDateJoined(invite.dateJoined)),
                              ),
                              DataCell(
                                ProfileStatusPill(status: invite.status.name),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SquareIconButton(
                                      icon: Icons.delete_outline,
                                      tooltip: 'Remove invite',
                                      size: 28,
                                      onTap: () => _confirmRemove(
                                        context,
                                        invite.email,
                                        () async => widget.onRemove(invite.id),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
      ],
    );
  }

  void _showInviteDialog(
    BuildContext context,
    Future<void> Function({required String email, required String role})
    onInvite,
  ) => showInviteMemberDialog(context, onInvite);

  void _showMemberDialog(
    BuildContext context,
    TeamMember member,
    ValueChanged<TeamMember> onUpdate,
  ) => showEditMemberDialog(context, member, onUpdate);

  Future<void> _confirmRemove(
    BuildContext context,
    String email,
    Future<void> Function() onConfirm,
  ) => showProfileConfirmDialog(
    context,
    title: 'Remove team member?',
    message: '$email will lose access to this organization.',
    confirmLabel: 'Remove member',
    onConfirm: onConfirm,
    destructive: true,
  );
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.count,
    required this.active,
    this.onTap,
  });
  final String label;
  final int count;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? context.colors.primary
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFE9E9FF)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: active
                        ? context.colors.primary
                        : const Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 8),
            Container(height: 2, width: 80, color: context.colors.primary),
          ],
        ],
      ),
    );
  }
}

class _MemberIdentity extends StatelessWidget {
  const _MemberIdentity({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFFE9FBFA),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.person, size: 18, color: Color(0xFF17C9BD)),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            email,
            style: context.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
