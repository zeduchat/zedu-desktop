import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Main area of the Files tab: the folders and files of the list picked in
/// [FilesSidebar].
class FilesView extends ConsumerWidget {
  const FilesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(filesProvider);
    final title = state.folderPath.isEmpty
        ? state.view.label
        : state.folderPath.last.name;

    return Container(
      color: colors.onPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.only(left: 24, right: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (state.view != FilesScope.trash) ...[
                  const _UploadButton(),
                  const SizedBox(width: 12),
                  _HeaderButton(
                    icon: Icons.create_new_folder_outlined,
                    label: 'New Folder',
                    onPressed: () => _newFolder(context),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  tooltip: 'Refresh',
                  icon: Icon(Icons.refresh, color: colors.textSecondary),
                  onPressed: () {
                    ref.invalidate(foldersListProvider);
                    ref.invalidate(filesListProvider);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                const FilesToolbar(),
                if (state.folderPath.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Breadcrumbs(state: state),
                ],
                const SizedBox(height: 16),
                _Tabs(selected: state.tab),
                const SizedBox(height: 24),
                Text(
                  state.tab == FilesTab.folders ? 'Folders' : 'Files',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (state.tab == FilesTab.folders)
                  const _FoldersSection()
                else
                  const _FilesSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `All files › docs › drafts`, each part going back to that level.
class _Breadcrumbs extends ConsumerWidget {
  const _Breadcrumbs({required this.state});

  final FilesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notifier = ref.read(filesProvider.notifier);
    final parts = [state.view.label, ...state.folderPath.map((f) => f.name)];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Icon(Icons.chevron_right, size: 18, color: colors.textHint),
          if (i == parts.length - 1)
            Text(
              parts[i],
              style: context.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            TextButton(
              onPressed: () => notifier.goToDepth(i),
              child: Text(parts[i]),
            ),
        ],
      ],
    );
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs({required this.selected});

  final FilesTab selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    Widget tab(FilesTab tab, String label) {
      final isSelected = tab == selected;
      return InkWell(
        onTap: () => ref.read(filesProvider.notifier).setTab(tab),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              color: isSelected ? colors.primary : colors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          tab(FilesTab.folders, 'Folders'),
          tab(FilesTab.files, 'Files'),
        ],
      ),
    );
  }
}

/// Looks up team members' names by user id, for the Owner column.
String Function(String) _ownerNames(WidgetRef ref) {
  final members = ref.watch(userProfileNotifierProvider).teamMembers;
  final names = {
    for (final m in members)
      if ((m.name ?? '').trim().isNotEmpty) m.id: m.name!.trim(),
  };
  return (userId) => names[userId] ?? 'Unknown';
}

class _FoldersSection extends ConsumerWidget {
  const _FoldersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersListProvider);
    final ownerName = _ownerNames(ref);

    return folders.when(
      loading: () => const _Loading(),
      error: (_, _) => _Message(
        icon: Icons.error_outline,
        title: 'Could not load folders',
        body: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(foldersListProvider),
      ),
      data: (page) {
        if (page.folders.isEmpty) {
          return const _Message(
            icon: Icons.folder_open_outlined,
            title: 'No folders',
            body: 'Folders in this list appear here.',
          );
        }
        final notifier = ref.read(filesProvider.notifier);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FoldersTable(
              folders: page.folders,
              ownerNameOf: ownerName,
              onOpen: notifier.openFolder,
            ),
            if (page.totalPages > 1)
              _Pagination(
                current: page.currentPage,
                total: page.totalPages,
                onChanged: notifier.setFolderPage,
              ),
          ],
        );
      },
    );
  }
}

class _FilesSection extends ConsumerWidget {
  const _FilesSection();

  Future<void> _open(BuildContext context, WorkspaceFile file) async {
    var opened = false;
    try {
      final uri = Uri.tryParse(file.link.trim());
      if (uri != null && uri.hasScheme && await canLaunchUrl(uri)) {
        opened = await launchUrl(uri);
      }
    } catch (_) {
      // Launcher errors can contain private paths; show only safe feedback.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Could not open this file. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                if (context.mounted) _open(context, file);
              },
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(filesListProvider);
    final sort = ref.watch(filesProvider.select((s) => s.sort));
    final ownerName = _ownerNames(ref);

    return page.when(
      loading: () => const _Loading(),
      error: (_, _) => _Message(
        icon: Icons.error_outline,
        title: 'Could not load files',
        body: 'Check your connection and try again.',
        onRetry: () => ref.invalidate(filesListProvider),
      ),
      data: (page) {
        if (page.files.isEmpty) {
          return const _Message(
            icon: Icons.insert_drive_file_outlined,
            title: 'No files',
            body:
                'Files in this list, or that match your filters, appear here.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilesTable(
              files: sort.apply(page.files),
              ownerNameOf: (file) =>
                  file.owner.isNotEmpty ? file.owner : ownerName(file.userId),
              onOpen: (file) => _open(context, file),
            ),
            if (page.totalPages > 1)
              _Pagination(
                current: page.currentPage,
                total: page.totalPages,
                onChanged: ref.read(filesProvider.notifier).setPage,
              ),
          ],
        );
      },
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.current,
    required this.total,
    required this.onChanged,
  });

  final int current;
  final int total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Previous page',
            icon: const Icon(Icons.chevron_left),
            onPressed: current > 1 ? () => onChanged(current - 1) : null,
          ),
          Text(
            'Page $current of $total',
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            icon: const Icon(Icons.chevron_right),
            onPressed: current < total ? () => onChanged(current + 1) : null,
          ),
        ],
      ),
    );
  }
}

Future<void> _newFolder(BuildContext context) async {
  final created = await CreateFolderDialog.show(context);
  if (created && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Folder created')));
  }
}

/// Picks files and uploads them, showing progress on the button.
class _UploadButton extends ConsumerWidget {
  const _UploadButton();

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) return;
    final files = result.files
        .where((PlatformFile f) => f.path != null)
        .map((PlatformFile f) => XFile(f.path!, name: f.name))
        .toList();
    if (files.isEmpty) return;

    final outcome = await ref
        .read(filesActionsProvider.notifier)
        .uploadFiles(files);
    if (!context.mounted) return;
    final failed = outcome.failedNames;
    final message = failed.isEmpty
        ? (outcome.uploaded == 1
              ? 'File uploaded'
              : '${outcome.uploaded} files uploaded')
        : outcome.uploaded == 0
        ? 'Could not upload ${failed.length == 1 ? failed.first : '${failed.length} files'}'
        : '${outcome.uploaded} uploaded, ${failed.length} failed: '
              '${failed.join(', ')}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadsLeft = ref.watch(
      filesActionsProvider.select((s) => s.uploadsLeft),
    );
    return _HeaderButton(
      icon: Icons.file_upload_outlined,
      label: uploadsLeft > 0 ? 'Uploading ($uploadsLeft)…' : 'Upload File',
      isBusy: uploadsLeft > 0,
      onPressed: uploadsLeft > 0 ? null : () => _upload(context, ref),
    );
  }
}

/// The outlined Upload File and New Folder buttons.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isBusy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        disabledForegroundColor: colors.primary.withValues(alpha: 0.6),
        side: BorderSide(color: colors.borderOutline),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: context.textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: isBusy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: CircularProgressIndicator(color: context.colors.primary),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: colors.textHint),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: colors.textHint,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
