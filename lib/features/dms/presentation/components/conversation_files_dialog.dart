import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// "View files" for a DM: every attachment in the conversation, newest first.
/// It loads the older pages too, and clicking a file opens it like a message
/// attachment does.
class ConversationFilesDialog extends StatefulWidget {
  const ConversationFilesDialog({
    super.key,
    required this.title,
    required this.history,
    this.openLink,
  });

  final String title;
  final ChatHistoryNotifier history;

  /// Opens a file's link. Defaults to [openMessageLink], which opens web links
  /// in the browser. Files whose link is not a web link can't be clicked.
  final Future<void> Function(String link)? openLink;

  @override
  State<ConversationFilesDialog> createState() =>
      _ConversationFilesDialogState();
}

class _ConversationFilesDialogState extends State<ConversationFilesDialog> {
  bool _loadingOlder = true;

  @override
  void initState() {
    super.initState();
    widget.history.addListener(_onHistory);
    widget.history.loadAll().whenComplete(() {
      if (mounted) setState(() => _loadingOlder = false);
    });
  }

  @override
  void dispose() {
    widget.history.removeListener(_onHistory);
    super.dispose();
  }

  void _onHistory() {
    if (mounted) setState(() {});
  }

  Future<void> _open(String link) async {
    final open = widget.openLink;
    if (open != null) return open(link);
    await openMessageLink(link);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final files = widget.history.messages
        .expand((message) => (message['media'] as List<dynamic>?) ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (files.isEmpty && !_loadingOlder)
              const Text('No files in this conversation yet.')
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final name = file['file_name']?.toString() ?? 'Attachment';
                    final link = file['file_link']?.toString() ?? '';
                    // The sender supplies the link, so only web links open.
                    final canOpen = messageLinkUri(link) != null;
                    return Tooltip(
                      message: canOpen
                          ? 'Open $name'
                          : link.isEmpty
                          ? 'No link for this file'
                          : "This file's link can't be opened",
                      child: ListTile(
                        enabled: canOpen,
                        mouseCursor: canOpen
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(name),
                        subtitle: Text(file['file_type']?.toString() ?? ''),
                        trailing: canOpen
                            ? Icon(
                                Icons.open_in_new,
                                size: 18,
                                color: colors.textHint,
                              )
                            : null,
                        onTap: canOpen ? () => _open(link) : null,
                      ),
                    );
                  },
                ),
              ),
            if (_loadingOlder)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Loading older files…',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
