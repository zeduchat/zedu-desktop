import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// "Rename file": edits a file's name, then saves it. Keeping the same name
/// just closes the dialog. A failure keeps it open with the reason.
class RenameFileDialog extends ConsumerWidget {
  const RenameFileDialog({super.key, required this.file});

  final WorkspaceFile file;

  /// Shows the dialog. Returns the new name when the file was renamed.
  static Future<String?> show(
    BuildContext context, {
    required WorkspaceFile file,
  }) => showDialog<String>(
    context: context,
    builder: (_) => RenameFileDialog(file: file),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = file.name;
    // Select the name without its extension, so typing keeps `.pdf`.
    final dot = name.lastIndexOf('.');
    return _RenameDialog(
      title: 'Rename file',
      label: 'File name',
      emptyError: 'Enter a file name.',
      connectionError: 'Failed to rename file. Please check your connection.',
      name: name,
      selectionEnd: dot > 0 ? dot : name.length,
      isRenaming: ref.watch(
        fileRenamesProvider.select((ids) => ids.contains(file.id)),
      ),
      rename: (newName) =>
          ref.read(fileRenamesProvider.notifier).rename(file, newName),
    );
  }
}

/// "Rename folder": edits a folder's name, then saves it, like
/// [RenameFileDialog] (Ziki #2719).
class RenameFolderDialog extends ConsumerWidget {
  const RenameFolderDialog({super.key, required this.folder});

  final FileFolder folder;

  /// Shows the dialog. Returns the new name when the folder was renamed.
  static Future<String?> show(
    BuildContext context, {
    required FileFolder folder,
  }) => showDialog<String>(
    context: context,
    builder: (_) => RenameFolderDialog(folder: folder),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) => _RenameDialog(
    title: 'Rename folder',
    label: 'Folder name',
    emptyError: 'Enter a folder name.',
    connectionError: 'Failed to rename folder. Please check your connection.',
    name: folder.name,
    selectionEnd: folder.name.length,
    isRenaming: ref.watch(
      folderRenamesProvider.select((ids) => ids.contains(folder.id)),
    ),
    rename: (newName) =>
        ref.read(folderRenamesProvider.notifier).rename(folder, newName),
  );
}

/// The name field and buttons the rename dialogs share. [rename] returns
/// what to tell the person when it failed, or null.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({
    required this.title,
    required this.label,
    required this.emptyError,
    required this.connectionError,
    required this.name,
    required this.selectionEnd,
    required this.isRenaming,
    required this.rename,
  });

  final String title;
  final String label;
  final String emptyError;
  final String connectionError;
  final String name;
  final int selectionEnd;
  final bool isRenaming;
  final Future<String?> Function(String name) rename;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.selectionEnd,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = widget.emptyError);
      return;
    }
    if (name == widget.name) {
      Navigator.of(context).pop();
      return;
    }
    try {
      final error = await widget.rename(name);
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pop(name);
      } else {
        setState(() => _error = error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = widget.connectionError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isRenaming = widget.isRenaming;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color),
    );

    return Dialog(
      backgroundColor: colors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: !isRenaming,
                maxLength: 255,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _rename(),
                style: context.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: widget.label,
                  counterText: '',
                  errorText: _error,
                  errorMaxLines: 3,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  enabledBorder: border(colors.divider),
                  focusedBorder: border(colors.primary),
                  errorBorder: border(colors.error),
                  focusedErrorBorder: border(colors.error),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isRenaming
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, value, _) => FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                      ),
                      onPressed: isRenaming || value.text.trim().isEmpty
                          ? null
                          : _rename,
                      child: Text(isRenaming ? 'Renaming…' : 'Rename'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
