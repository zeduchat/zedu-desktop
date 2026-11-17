import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// "Info": a panel from the right with a file's preview and details, as on
/// web. It shows what the list knows at once, then the server's current
/// details.
class FileInfoPanel extends ConsumerWidget {
  const FileInfoPanel({super.key, required this.file, required this.owner});

  /// The file as the list shows it.
  final WorkspaceFile file;

  /// The owner's name, as the list shows it.
  final String owner;

  static const width = 380.0;

  static Future<void> show(
    BuildContext context, {
    required WorkspaceFile file,
    required String owner,
  }) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close file info',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => Align(
      alignment: Alignment.centerRight,
      child: FileInfoPanel(file: file, owner: owner),
    ),
    transitionBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final details = ref.watch(fileDetailsProvider(file.id));
    final current = details.value ?? file;
    final info = ref.watch(fileInfoProvider(file.id));
    final sharedIn = info is AsyncData<WorkspaceFileInfo>
        ? info.value.sharedInLabel
        : '';

    final labelStyle = context.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: colors.textSecondary,
    );
    final valueStyle = labelStyle?.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w500,
    );

    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: labelStyle)),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
    Widget text(String value) =>
        Text(value, textAlign: TextAlign.right, style: valueStyle);

    final access = switch (current.accessType) {
      'public' => 'Public',
      'private' => 'Private',
      _ => null,
    };

    return Material(
      color: colors.onPrimary,
      elevation: 8,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: colors.textPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Info',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close file info',
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _PreviewCard(file: current),
                  const SizedBox(height: 24),
                  Text(
                    'Details',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  row(
                    'Owner',
                    text(current.owner.isNotEmpty ? current.owner : owner),
                  ),
                  if (access != null)
                    row(
                      'Access',
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          access,
                          style: valueStyle?.copyWith(
                            fontSize: 12,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  row(
                    'Date uploaded',
                    text(formatFileDateTime(current.createdAt)),
                  ),
                  row(
                    'Date modified',
                    text(formatFileDateTime(current.modifiedAt)),
                  ),
                  row(
                    'Shared in',
                    text(
                      sharedIn.isNotEmpty
                          ? sharedIn
                          : (current.sharedIn.isEmpty ? '—' : current.sharedIn),
                    ),
                  ),
                  row('File size', text(formatFileSize(current.size))),
                  row(
                    'Location',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(child: text(_location(ref, current.folderId))),
                      ],
                    ),
                  ),
                  if (details.isLoading) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      minHeight: 2,
                      color: colors.primary,
                      backgroundColor: colors.divider,
                    ),
                  ],
                  if (details.hasError) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Could not load the latest details. '
                      'Showing what the list has.',
                      style: labelStyle?.copyWith(color: colors.error),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () =>
                            ref.invalidate(fileDetailsProvider(file.id)),
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The folder holding the file: from the folders being browsed, else the
  /// top-level folders, else "All files" when it is in none.
  static String _location(WidgetRef ref, String folderId) {
    if (folderId.isEmpty) return 'All files';
    final path = ref.watch(filesProvider.select((s) => s.folderPath));
    for (final folder in path) {
      if (folder.id == folderId) return folder.name;
    }
    final folders =
        ref.watch(moveTargetFoldersProvider(null)).value ?? const [];
    for (final folder in folders) {
      if (folder.id == folderId) return folder.name;
    }
    return 'A folder';
  }
}

/// The file's icon, name and type over a preview: the image itself for
/// images, else "No preview available".
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.file});

  final WorkspaceFile file;

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppToastService.show(
      context,
      type: AppToastType.success,
      message: 'File name copied',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hintStyle = context.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: colors.textSecondary,
    );
    Widget noPreview() => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.insert_drive_file_outlined,
          size: 40,
          color: colors.textSecondary,
        ),
        const SizedBox(height: 8),
        Text('No preview available', style: hintStyle),
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.primaryBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    file.isImage
                        ? Icons.image_outlined
                        : Icons.insert_drive_file_outlined,
                    color: colors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              file.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy file name',
                            visualDensity: const VisualDensity(
                              horizontal: VisualDensity.minimumDensity,
                              vertical: VisualDensity.minimumDensity,
                            ),
                            iconSize: 16,
                            color: colors.textSecondary,
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copy(context, file.name),
                          ),
                        ],
                      ),
                      if (file.fileType.isNotEmpty)
                        Text(
                          file.fileType.toUpperCase(),
                          style: hintStyle?.copyWith(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            color: colors.primaryBg,
            child: file.link.isEmpty
                ? noPreview()
                : switch (FilePreviewKind.of(file)) {
                    FilePreviewKind.svg => SvgPicture.network(
                      file.link,
                      fit: BoxFit.contain,
                      semanticsLabel: file.name,
                      errorBuilder: (_, _, _) => noPreview(),
                    ),
                    FilePreviewKind.image => Image.network(
                      file.link,
                      fit: BoxFit.contain,
                      semanticLabel: file.name,
                      errorBuilder: (_, _, _) => noPreview(),
                    ),
                    _ => noPreview(),
                  },
          ),
        ],
      ),
    );
  }
}
