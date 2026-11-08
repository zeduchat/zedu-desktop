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
    // Folders are one level deep on the backend: it ignores parent_id, so
    // inside a folder there are no subfolders to list or create.
    final inFolder = state.folderPath.isNotEmpty;
    final tab = inFolder ? FilesTab.files : state.tab;

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
                  if (!inFolder) ...[
                    _HeaderButton(
                      icon: Icons.create_new_folder_outlined,
                      label: 'New Folder',
                      onPressed: () => _newFolder(context),
                    ),
                    const SizedBox(width: 8),
                  ],
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
                if (!inFolder) ...[
                  _Tabs(selected: tab),
                  const SizedBox(height: 24),
                ],
                Text(
                  tab == FilesTab.folders ? 'Folders' : 'Files',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (tab == FilesTab.folders)
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
              onDelete: (folder) => _deleteFolder(context, ref, folder),
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

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    WorkspaceFile file,
  ) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final outcome = await ref
        .read(fileDownloadsProvider.notifier)
        .download(file);
    if (!overlay.mounted) return;
    switch (outcome.status) {
      case FileDownloadStatus.cancelled:
        return;
      case FileDownloadStatus.saved:
        final folder = _folderName(outcome.path!);
        AppToastService.showWith(
          overlay,
          type: AppToastType.success,
          message: folder.isEmpty
              ? 'Downloaded ${file.name}.'
              : 'Downloaded ${file.name} to $folder.',
        );
      case FileDownloadStatus.failed:
        AppToastService.showWith(
          overlay,
          type: AppToastType.error,
          message: outcome.message!,
        );
    }
  }

  Future<void> _rename(BuildContext context, WorkspaceFile file) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final newName = await RenameFileDialog.show(context, file: file);
    if (newName == null || !overlay.mounted) return;
    AppToastService.showWith(
      overlay,
      type: AppToastType.success,
      message: 'Renamed ${file.name} to $newName.',
    );
  }

  Future<void> _move(BuildContext context, WorkspaceFile file) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final folder = await MoveFileDialog.show(context, file: file);
    if (folder == null || !overlay.mounted) return;
    AppToastService.showWith(
      overlay,
      type: AppToastType.success,
      message: 'Moved ${file.name} to ${folder.name}.',
    );
  }

  Future<void> _share(BuildContext context, WorkspaceFile file) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final outcome = await ShareFileDialog.show(context, file: file);
    if (outcome == null || !overlay.mounted) return;
    AppToastService.showWith(
      overlay,
      type: outcome.complete ? AppToastType.success : AppToastType.info,
      message: outcome.message,
    );
  }

  void _preview(BuildContext context, WidgetRef ref, WorkspaceFile file) =>
      FilePreviewDialog.show(
        context,
        file: file,
        onDownload: () {
          if (context.mounted) _download(context, ref, file);
        },
        onOpenExternally: () {
          if (context.mounted) _open(context, file);
        },
      );

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref,
    WorkspaceFile file,
  ) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final error = await ref.read(pinnedFilesProvider.notifier).toggle(file);
    if (error == null || !overlay.mounted) return;
    AppToastService.showWith(overlay, type: AppToastType.error, message: error);
  }

  Future<void> _delete(
    BuildContext context,
    WorkspaceFile file, {
    required bool permanent,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final deleted = await DeleteFileDialog.show(
      context,
      file: file,
      permanent: permanent,
    );
    if (!deleted || !overlay.mounted) return;
    AppToastService.showWith(
      overlay,
      type: AppToastType.success,
      message: permanent
          ? 'Deleted ${file.name} permanently.'
          : 'Moved ${file.name} to Deleted files.',
    );
  }

  /// Restores [file] from Deleted files and says how it went. On success the
  /// list reloads without it; on failure the row stays.
  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    WorkspaceFile file,
  ) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final error = await ref.read(fileRestoresProvider.notifier).restore(file);
    if (!overlay.mounted) return;
    AppToastService.showWith(
      overlay,
      type: error == null ? AppToastType.success : AppToastType.error,
      message: error ?? 'Restored ${file.name}.',
    );
  }

  /// Name of the folder holding [path], such as `Downloads`.
  static String _folderName(String path) {
    final parts = path.split(RegExp(r'[\\/]'))..removeWhere((p) => p.isEmpty);
    return parts.length < 2 ? '' : parts[parts.length - 2];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(filesListProvider);
    final sort = ref.watch(filesProvider.select((s) => s.sort));
    final scope = ref.watch(filesProvider.select((s) => s.view));
    final downloads = ref.watch(fileDownloadsProvider);
    final isTrash = scope == FilesScope.trash;
    // Deleted files can't be pinned, so they show no pins either.
    final pinnedIds = isTrash
        ? const <String>{}
        : ref.watch(pinnedFilesProvider).value ?? const <String>{};
    final ownerName = _ownerNames(ref);
    final myId = ref.watch(authNotifierProvider.select((s) => s.user?.id));

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
        Widget table(List<WorkspaceFile> files) => FilesTable(
          files: files,
          ownerNameOf: (file) =>
              file.owner.isNotEmpty ? file.owner : ownerName(file.userId),
          // Clicking a file previews it in the app, as on web. Deleted files
          // still open outside it.
          onOpen: isTrash
              ? (file) => _open(context, file)
              : (file) => _preview(context, ref, file),
          downloads: downloads,
          pinnedIds: pinnedIds,
          onDownload: isTrash ? null : (file) => _download(context, ref, file),
          onPreview: isTrash ? null : (file) => _preview(context, ref, file),
          onTogglePin: isTrash
              ? null
              : (file) => _togglePin(context, ref, file),
          onRename: isTrash ? null : (file) => _rename(context, file),
          onMove: isTrash ? null : (file) => _move(context, file),
          onShare: isTrash ? null : (file) => _share(context, file),
          // zedu-be lets only the person who uploaded a file share it, so
          // other people's files don't offer a Share that can only fail.
          canShare: (file) => myId != null && file.userId == myId,
          onInfo: isTrash
              ? null
              : (file) => FileInfoPanel.show(
                  context,
                  file: file,
                  owner: file.owner.isNotEmpty
                      ? file.owner
                      : ownerName(file.userId),
                ),
          onRestore: isTrash ? (file) => _restore(context, ref, file) : null,
          onDelete: (file) => _delete(context, file, permanent: isTrash),
          deletesPermanently: isTrash,
        );

        // Pinned files on this page come first, under their own heading, as
        // on web.
        final files = sort.apply(page.files);
        final pinned = [
          for (final f in files)
            if (pinnedIds.contains(f.id)) f,
        ];
        final others = [
          for (final f in files)
            if (!pinnedIds.contains(f.id)) f,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pinned.isNotEmpty) ...[
              const _PinnedHeading(),
              const SizedBox(height: 8),
              table(pinned),
              if (others.isNotEmpty) const SizedBox(height: 24),
            ],
            if (others.isNotEmpty) table(others),
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

Future<void> _deleteFolder(
  BuildContext context,
  WidgetRef ref,
  FileFolder folder,
) async {
  final colors = context.colors;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: colors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text('Delete "${folder.name}"?'),
      content: const Text(
        'The folder and everything inside it will be deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final error = await ref
      .read(filesActionsProvider.notifier)
      .deleteFolder(folder);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error ?? 'Folder deleted')));
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
    final message = outcome.workspaceChanged
        ? 'Workspace changed. ${outcome.skippedNames.length} remaining files '
              'were not uploaded. A file already in progress may have '
              'completed in the previous workspace.'
        : failed.isEmpty
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

/// "Pinned files", over the files the user pinned.
class _PinnedHeading extends StatelessWidget {
  const _PinnedHeading();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(Icons.push_pin_outlined, size: 16, color: colors.textSecondary),
        const SizedBox(width: 6),
        Text(
          'Pinned files',
          style: context.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
