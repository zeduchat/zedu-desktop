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
  final text = size >= 10 || size == size.roundToDouble()
      ? size.round().toString()
      : size.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

String formatItemCount(int count) => count == 1 ? '1 item' : '$count items';

/// Below this width the Owner and Shared in columns are hidden.
const _compactWidth = 720.0;

class _Column {
  const _Column(this.label, this.flex, {this.compact = true});

  final String label;
  final int flex;

  /// Whether the column stays when the table is narrow.
  final bool compact;
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

        Widget row(List<Widget> cells, {bool header = false}) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: header ? 12 : 14,
          ),
          child: Row(
            children: [
              for (final i in shown)
                Expanded(flex: columns[i].flex, child: cells[i]),
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

Widget _nameCell(BuildContext context, Widget icon, String name) => Row(
  children: [
    icon,
    const SizedBox(width: 14),
    Expanded(
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
  ],
);

class FoldersTable extends StatelessWidget {
  const FoldersTable({
    super.key,
    required this.folders,
    required this.ownerNameOf,
    required this.onOpen,
  });

  final List<FileFolder> folders;
  final String Function(String userId) ownerNameOf;
  final ValueChanged<FileFolder> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _Table(
      columns: const [
        _Column('Name', 5),
        _Column('Owner', 2, compact: false),
        _Column('Date Created', 2),
        _Column('Items', 1),
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
  });

  final List<WorkspaceFile> files;
  final String Function(WorkspaceFile file) ownerNameOf;
  final ValueChanged<WorkspaceFile> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _Table(
      columns: const [
        _Column('Name', 5),
        _Column('Shared in', 2, compact: false),
        _Column('Owner', 2, compact: false),
        _Column('Date Modified', 2),
        _Column('Size', 1),
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
          ),
          _cellText(context, file.sharedIn.isEmpty ? '—' : file.sharedIn),
          _cellText(context, ownerNameOf(file)),
          _cellText(context, formatFileDate(file.modifiedAt)),
          _cellText(context, formatFileSize(file.size)),
        ];
      },
    );
  }
}
