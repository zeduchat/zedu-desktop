import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `Nov 1, 2026`, or `—` when there is no date.
String formatFileDate(DateTime? date) =>
    date == null ? '—' : '${_months[date.month - 1]} ${date.day}, ${date.year}';

/// `Nov 4, 2026, 6:59 PM`.
String formatFileDateTime(DateTime? date) {
  if (date == null) return '—';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${formatFileDate(date)}, $hour:$minute $period';
}

/// `512 B`, `1.5 KB`, `12 MB`, …
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  // Round to one decimal, then step up a unit when that rounds to a whole
  // 1024, so 1023.9 KB reads 1 MB instead of an impossible 1024 KB.
  var one = (size * 10).round() / 10;
  while (one.round() >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
    one = (size * 10).round() / 10;
  }
  final text = one >= 10 || one == one.roundToDouble()
      ? one.round().toString()
      : one.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

String formatItemCount(int count) => count == 1 ? '1 item' : '$count items';

/// Below this width the Owner and Shared in columns are hidden.
const _compactWidth = 720.0;

/// Horizontal padding on each side of a table row.
const _rowPadding = 20.0;

class _Column {
  const _Column(
    this.label,
    this.flex, {
    this.compact = true,
    this.minWidth = 0,
  });

  final String label;
  final int flex;

  /// Whether the column stays when the table is narrow.
  final bool compact;

  /// Width the column keeps when its flex share would be smaller, so short
  /// values such as `120 KB` aren't cut off.
  final double minWidth;
}

/// Widths of [columns] in [width]: null for a column sized by its flex, or
/// the fixed width of a column whose flex share is below its minimum. When
/// the minimums don't fit, every column falls back to its flex.
List<double?> _columnWidths(List<_Column> columns, double width) {
  final widths = List<double?>.filled(columns.length, null);
  var changed = true;
  while (changed) {
    changed = false;
    var remaining = width;
    var flex = 0;
    for (var i = 0; i < columns.length; i++) {
      final fixed = widths[i];
      if (fixed != null) {
        remaining -= fixed;
      } else {
        flex += columns[i].flex;
      }
    }
    if (remaining < 0) return List.filled(columns.length, null);
    for (var i = 0; i < columns.length; i++) {
      if (widths[i] != null) continue;
      if (remaining * columns[i].flex / flex < columns[i].minWidth) {
        widths[i] = columns[i].minWidth;
        changed = true;
      }
    }
  }
  return widths;
}

class _Table extends StatelessWidget {
  const _Table({
    required this.columns,
    required this.rowCount,
    required this.cellsOf,
    this.onTapRow,
  });

  final List<_Column> columns;
  final int rowCount;
  final List<Widget> Function(int row) cellsOf;
  final ValueChanged<int>? onTapRow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _compactWidth;
        final shown = [
          for (var i = 0; i < columns.length; i++)
            if (!isCompact || columns[i].compact) i,
        ];
        final widths = _columnWidths([
          for (final i in shown) columns[i],
        ], constraints.maxWidth - _rowPadding * 2);

        Widget row(List<Widget> cells, {bool header = false}) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _rowPadding,
            vertical: header ? 12 : 14,
          ),
          child: Row(
            children: [
              for (var k = 0; k < shown.length; k++)
                if (widths[k] case final width?)
                  SizedBox(width: width, child: cells[shown[k]])
                else
                  Expanded(
                    flex: columns[shown[k]].flex,
                    child: cells[shown[k]],
                  ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: row(header: true, [
                for (final column in columns)
                  Text(
                    column.label,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
              ]),
            ),
            for (var r = 0; r < rowCount; r++)
              Material(
                color: colors.onPrimary,
                child: InkWell(
                  onTap: onTapRow == null ? null : () => onTapRow!(r),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colors.divider)),
                    ),
                    child: row(cellsOf(r)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Widget _cellText(BuildContext context, String text) => Text(
  text,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: context.textTheme.bodyMedium?.copyWith(
    fontSize: 13,
    color: context.colors.textPrimary,
  ),
);

/// The channels a file was shared in.
///
/// The files list does not carry that, so it comes from the file's own info
/// route. While it loads, and for a file shared nowhere, the cell keeps the
/// dash the list used to show.
class _SharedInCell extends ConsumerWidget {
  const _SharedInCell(this.file, {super.key});

  final WorkspaceFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(fileInfoProvider(file.id));
    final sharedIn = info is AsyncData<WorkspaceFileInfo>
        ? info.value.sharedInLabel
        : '';
    final text = sharedIn.isNotEmpty ? sharedIn : file.sharedIn;
    return _cellText(context, text.isEmpty ? '—' : text);
  }
}

Widget _nameCell(
  BuildContext context,
  Widget icon,
  String name, {
  Widget? trailing,
}) => Row(
  children: [
    icon,
    const SizedBox(width: 14),
    Flexible(
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.titleSmall?.copyWith(
          color: context.colors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    if (trailing != null) ...[const SizedBox(width: 6), trailing],
  ],
);

class FoldersTable extends StatelessWidget {
  const FoldersTable({
    super.key,
    required this.folders,
    required this.ownerNameOf,
    required this.onOpen,
    this.onDelete,
  });

  final List<FileFolder> folders;
  final String Function(String userId) ownerNameOf;
  final ValueChanged<FileFolder> onOpen;
  final ValueChanged<FileFolder>? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _Table(
      columns: [
        const _Column('Name', 5),
        const _Column('Owner', 2, compact: false),
        const _Column('Date Created', 2),
        const _Column('Items', 1),
        if (onDelete != null) const _Column('', 1),
      ],
      rowCount: folders.length,
      onTapRow: (r) => onOpen(folders[r]),
      cellsOf: (r) {
        final folder = folders[r];
        return [
          _nameCell(
            context,
            Icon(Icons.folder, color: colors.primary, size: 22),
            folder.name,
          ),
          _cellText(context, ownerNameOf(folder.userId)),
          _cellText(context, formatFileDate(folder.createdAt)),
          _cellText(context, formatItemCount(folder.itemCount)),
          if (onDelete != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Delete folder',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: Icon(Icons.delete_outline, size: 18, color: colors.error),
                onPressed: () => onDelete!(folder),
              ),
            ),
        ];
      },
    );
  }
}

class FilesTable extends StatelessWidget {
  const FilesTable({
    super.key,
    required this.files,
    required this.ownerNameOf,
    required this.onOpen,
    this.onDownload,
    this.onPreview,
    this.onRename,
    this.onMove,
    this.onShare,
    this.canShare,
    this.onTogglePin,
    this.pinnedIds = const {},
    this.onInfo,
    this.onRestore,
    this.onDelete,
    this.deletesPermanently = false,
    this.downloads = const {},
  });

  final List<WorkspaceFile> files;
  final String Function(WorkspaceFile file) ownerNameOf;
  final ValueChanged<WorkspaceFile> onOpen;

  /// Downloads a file. When null, as in Deleted files, the menu has no
  /// Download.
  final ValueChanged<WorkspaceFile>? onDownload;

  /// Previews a file in the app. When null, the menu has no Preview.
  final ValueChanged<WorkspaceFile>? onPreview;

  /// Renames a file. When null, as in Deleted files, the menu has no Rename.
  final ValueChanged<WorkspaceFile>? onRename;

  /// Moves a file into a folder. When null, as in Deleted files, the menu has
  /// no Move.
  final ValueChanged<WorkspaceFile>? onMove;

  /// Shares a file with workspace members. When null, as in Deleted files,
  /// the menu has no Share.
  final ValueChanged<WorkspaceFile>? onShare;

  /// Whether [onShare] is offered for a file. When null, every file has it.
  final bool Function(WorkspaceFile file)? canShare;

  /// Pins a file, or unpins it when it is in [pinnedIds]. When null, as in
  /// Deleted files, the menu has neither.
  final ValueChanged<WorkspaceFile>? onTogglePin;

  /// Ids of the pinned files, marked with a pin by their name.
  final Set<String> pinnedIds;

  /// Shows a file's details. When null, as in Deleted files, the menu has no
  /// Info.
  final ValueChanged<WorkspaceFile>? onInfo;

  /// Restores a file from Deleted files. When null, the menu has no Restore.
  final ValueChanged<WorkspaceFile>? onRestore;

  /// Deletes a file. When null, the menu has no Delete.
  final ValueChanged<WorkspaceFile>? onDelete;

  /// Whether Delete removes files for good, as in Deleted files. The menu then
  /// says Delete permanently.
  final bool deletesPermanently;

  /// Downloads in progress, by file id: the share downloaded, or null while
  /// the size is unknown.
  final Map<String, double?> downloads;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final download = onDownload;
    final preview = onPreview;
    final rename = onRename;
    final move = onMove;
    final share = onShare;
    final togglePin = onTogglePin;
    final info = onInfo;
    final restore = onRestore;
    final delete = onDelete;
    final hasActions =
        download != null ||
        preview != null ||
        rename != null ||
        move != null ||
        share != null ||
        togglePin != null ||
        info != null ||
        restore != null ||
        delete != null;

    return _Table(
      columns: [
        // Room for the icon and the start of the name.
        const _Column('Name', 5, minWidth: 64),
        const _Column('Shared in', 2, compact: false),
        const _Column('Owner', 2, compact: false),
        // Wide enough for the header and `Nov 30, 2026`, and for the longest
        // size, such as `1023 KB`.
        const _Column('Date Modified', 2, minWidth: 104),
        const _Column('Size', 1, minWidth: 64),
        if (hasActions) const _Column('', 1, minWidth: 32),
      ],
      rowCount: files.length,
      onTapRow: (r) => onOpen(files[r]),
      cellsOf: (r) {
        final file = files[r];
        return [
          _nameCell(
            context,
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
            file.name,
            trailing: pinnedIds.contains(file.id)
                ? Tooltip(
                    message: 'Pinned',
                    child: Icon(
                      Icons.push_pin,
                      size: 14,
                      color: colors.primary,
                    ),
                  )
                : null,
          ),
          _SharedInCell(file, key: ValueKey('shared-in-${file.id}')),
          _cellText(context, ownerNameOf(file)),
          _cellText(context, formatFileDate(file.modifiedAt)),
          _cellText(context, formatFileSize(file.size)),
          if (hasActions)
            Align(
              alignment: Alignment.centerRight,
              child: _FileActionsMenu(
                fileName: file.name,
                isDownloading: downloads.containsKey(file.id),
                progress: downloads[file.id],
                onDownload: download == null ? null : () => download(file),
                onPreview: preview == null ? null : () => preview(file),
                onRename: rename == null ? null : () => rename(file),
                onMove: move == null ? null : () => move(file),
                onShare: share == null || !(canShare?.call(file) ?? true)
                    ? null
                    : () => share(file),
                onTogglePin: togglePin == null ? null : () => togglePin(file),
                isPinned: pinnedIds.contains(file.id),
                onInfo: info == null ? null : () => info(file),
                onRestore: restore == null ? null : () => restore(file),
                onDelete: delete == null ? null : () => delete(file),
                deleteLabel: deletesPermanently
                    ? 'Delete permanently'
                    : 'Delete',
              ),
            ),
        ];
      },
    );
  }
}

enum _FileAction {
  download,
  preview,
  pin,
  share,
  rename,
  move,
  info,
  restore,
  delete,
}

/// The ⋮ menu of a file row, holding the actions on that file. While the file
/// downloads it shows a progress ring instead.
class _FileActionsMenu extends StatelessWidget {
  const _FileActionsMenu({
    required this.fileName,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
    required this.onPreview,
    required this.onRename,
    required this.onMove,
    required this.onShare,
    required this.onTogglePin,
    required this.isPinned,
    required this.onInfo,
    required this.onRestore,
    required this.onDelete,
    required this.deleteLabel,
  });

  final String fileName;
  final bool isDownloading;
  final double? progress;
  final VoidCallback? onDownload;
  final VoidCallback? onPreview;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onShare;
  final VoidCallback? onTogglePin;
  final bool isPinned;
  final VoidCallback? onInfo;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (isDownloading) {
      final percent = progress == null ? '' : ' ${(progress! * 100).round()}%';
      return Tooltip(
        message: 'Downloading$percent',
        child: SizedBox.square(
          dimension: 32,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              color: colors.primary,
              backgroundColor: colors.divider,
            ),
          ),
        ),
      );
    }

    PopupMenuItem<_FileAction> item(
      _FileAction value,
      IconData icon,
      String label, {
      bool destructive = false,
    }) => PopupMenuItem(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: destructive ? colors.error : colors.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: destructive ? colors.error : colors.textPrimary,
            ),
          ),
        ],
      ),
    );

    return PopupMenuButton<_FileAction>(
      tooltip: 'More actions for $fileName',
      position: PopupMenuPosition.under,
      color: colors.onPrimary,
      padding: EdgeInsets.zero,
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 160),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(32),
        minimumSize: const Size.square(32),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(Icons.more_vert, color: colors.textSecondary),
      onSelected: (action) => switch (action) {
        _FileAction.download => onDownload?.call(),
        _FileAction.preview => onPreview?.call(),
        _FileAction.pin => onTogglePin?.call(),
        _FileAction.share => onShare?.call(),
        _FileAction.rename => onRename?.call(),
        _FileAction.move => onMove?.call(),
        _FileAction.info => onInfo?.call(),
        _FileAction.restore => onRestore?.call(),
        _FileAction.delete => onDelete?.call(),
      },
      itemBuilder: (context) => [
        if (onDownload != null)
          item(_FileAction.download, Icons.download_outlined, 'Download'),
        if (onPreview != null)
          item(_FileAction.preview, Icons.visibility_outlined, 'Preview'),
        if (onTogglePin != null)
          item(
            _FileAction.pin,
            isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            isPinned ? 'Unpin' : 'Pin',
          ),
        if (onShare != null)
          item(_FileAction.share, Icons.share_outlined, 'Share'),
        if (onRename != null)
          item(_FileAction.rename, Icons.drive_file_rename_outline, 'Rename'),
        if (onMove != null)
          item(_FileAction.move, Icons.drive_file_move_outline, 'Move'),
        if (onInfo != null) item(_FileAction.info, Icons.info_outline, 'Info'),
        if (onRestore != null)
          item(_FileAction.restore, Icons.restore, 'Restore'),
        if (onDelete != null)
          item(
            _FileAction.delete,
            Icons.delete_outline,
            deleteLabel,
            destructive: true,
          ),
      ],
    );
  }
}
