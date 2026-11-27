import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class RolesAndPermissionsSection extends StatelessWidget {
  const RolesAndPermissionsSection({super.key, required this.roles});

  final List<RolePermission> roles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(
          title: 'Roles & permissions',
          subtitle:
              'Define and manage roles, then assign their associated permissions.',
        ),
        const SizedBox(height: 28),
        for (final role in roles) ...[
          _RoleCard(role: role),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// A role, its description and, once opened, the permissions it grants.
class _RoleCard extends StatefulWidget {
  const _RoleCard({required this.role});
  final RolePermission role;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final hint = context.colors.textSecondary;
    return Semantics(
      button: true,
      expanded: _expanded,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: ProfileCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    role.role,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.keyboard_arrow_right,
                      size: 20,
                      color: hint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                role.description,
                style: context.textTheme.bodySmall?.copyWith(color: hint),
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                if (role.permissions.isEmpty)
                  Text(
                    'No permissions listed for this role.',
                    style: context.textTheme.bodySmall?.copyWith(color: hint),
                  )
                else
                  for (final permission in role.permissions)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: hint,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              permission,
                              style: context.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
