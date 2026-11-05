import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Left column of the Files tab: All files, My files, Shared with me and
/// Deleted files.
class FilesSidebar extends ConsumerWidget {
  const FilesSidebar({super.key});

  static IconData iconFor(FilesScope view) => switch (view) {
    FilesScope.all => Icons.file_copy_outlined,
    FilesScope.mine => Icons.insert_drive_file_outlined,
    FilesScope.shared => Icons.people_outline,
    FilesScope.trash => Icons.delete_outline,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selected = ref.watch(filesProvider.select((s) => s.view));

    return Container(
      width: 320,
      color: colors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSwitcherHeader(),
          const SizedBox(height: 12),
          Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final view in FilesScope.values)
                  _SidebarItem(
                    icon: iconFor(view),
                    label: view.label,
                    isSelected: view == selected,
                    onTap: () =>
                        ref.read(filesProvider.notifier).selectView(view),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = colors.onPrimary.withValues(
      alpha: isSelected ? 1 : 0.85,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.onPrimary.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    color: foreground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
