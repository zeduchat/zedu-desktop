import 'package:zedu/core/core.dart';
import 'package:zedu/features/tasks/domain/domain.dart';

class AssignedTaskNextActionChecklist extends StatefulWidget {
  const AssignedTaskNextActionChecklist({
    super.key,
    required this.input,
    this.initialRole = TaskRole.contributor,
    this.onRoleChanged,
  });

  final TaskChecklistStateInput input;
  final TaskRole initialRole;
  final ValueChanged<TaskRole>? onRoleChanged;

  @override
  State<AssignedTaskNextActionChecklist> createState() =>
      _AssignedTaskNextActionChecklistState();
}

class _AssignedTaskNextActionChecklistState
    extends State<AssignedTaskNextActionChecklist> {
  late TaskRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  void _setRole(TaskRole role) {
    if (_selectedRole == role) return;
    setState(() => _selectedRole = role);
    widget.onRoleChanged?.call(role);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final items = TaskChecklistService.generateItems(
      role: _selectedRole,
      input: widget.input,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderOutline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Next Actions & Checklist',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              if (widget.input.deliverBy != null) ...[
                _buildDeadlineBadge(colors, widget.input.deliverBy!),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _buildRoleSelector(colors),
          const SizedBox(height: 14),
          if (_selectedRole == TaskRole.reviewer && widget.input.isOwnAgent) ...[
            _buildOwnerIndependenceWarning(colors),
            const SizedBox(height: 12),
          ],
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildChecklistItemTile(context, colors, items[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineBadge(AppPalette colors, DateTime deliverBy) {
    final remaining = deliverBy.difference(DateTime.now());
    final isOverdue = remaining.isNegative;
    final hours = remaining.inHours.abs();
    final minutes = (remaining.inMinutes.abs() % 60);

    final text = isOverdue
        ? 'Overdue by ${hours}h ${minutes}m'
        : 'Deliver by: ${hours}h ${minutes}m left';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOverdue ? colors.errorBg : colors.primaryBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOverdue ? colors.error : colors.primary,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 13,
            color: isOverdue ? colors.error : colors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOverdue ? colors.error : colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector(AppPalette colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TaskRole.values.map((role) {
          final isSelected = role == _selectedRole;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                role.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colors.onPrimary : colors.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: colors.primary,
              backgroundColor: colors.background,
              side: BorderSide(
                color: isSelected ? colors.primary : colors.borderOutline,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onSelected: (_) => _setRole(role),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOwnerIndependenceWarning(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Owner-Independence Exclusion Active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Agents owned by the same user account cannot review or submit verdicts for their own claims. Fixes must be reviewed by independent agents.',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItemTile(
    BuildContext context,
    AppPalette colors,
    TaskChecklistItem item,
  ) {
    final (icon, iconColor) = () {
      if (item.isBlocked) {
        return (Icons.block_rounded, colors.error);
      }
      if (item.isCompleted) {
        return (Icons.check_circle_rounded, colors.success);
      }
      return (Icons.radio_button_unchecked_rounded, colors.textHint);
    }();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: item.isBlocked ? colors.errorBg : colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.isBlocked
              ? colors.error.withValues(alpha: 0.3)
              : colors.borderOutline,
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: item.isBlocked
                              ? colors.error
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildBadgePill(colors, item.badge),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                ),
                if (item.blockedReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.blockedReason!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgePill(AppPalette colors, TaskChecklistBadge badge) {
    final (bgColor, fgColor) = switch (badge) {
      TaskChecklistBadge.required => (colors.primaryBg, colors.primary),
      TaskChecklistBadge.recommended => (colors.successBg, colors.success),
      TaskChecklistBadge.automated => (colors.background, colors.textSecondary),
      TaskChecklistBadge.readOnly => (colors.background, colors.textHint),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fgColor,
        ),
      ),
    );
  }
}
