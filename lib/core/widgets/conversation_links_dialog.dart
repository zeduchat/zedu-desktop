import 'package:zedu/core/core.dart';

/// Message data needed to build a conversation's shared-links list.
class ConversationLinkSource {
  const ConversationLinkSource({
    required this.content,
    required this.author,
    required this.sharedAt,
  });

  final String content;
  final String author;
  final DateTime? sharedAt;
}

/// A distinct web link and the newest message that shared it.
class ConversationLink {
  const ConversationLink({
    required this.uri,
    required this.author,
    required this.sharedAt,
  });

  final Uri uri;
  final String author;
  final DateTime? sharedAt;
}

/// Extracts distinct HTTP(S) URLs and orders them by their newest share.
List<ConversationLink> buildConversationLinks(
  Iterable<ConversationLinkSource> messages,
) {
  final newestFirst = messages.toList()
    ..sort((a, b) {
      final aTime = a.sharedAt;
      final bTime = b.sharedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
  final seen = <String>{};
  final links = <ConversationLink>[];
  for (final message in newestFirst) {
    for (final uri in extractMessageLinks(message.content)) {
      final key = uri
          .replace(
            scheme: uri.scheme.toLowerCase(),
            host: uri.host.toLowerCase(),
          )
          .toString();
      if (!seen.add(key)) continue;
      links.add(
        ConversationLink(
          uri: uri,
          author: message.author,
          sharedAt: message.sharedAt,
        ),
      );
    }
  }
  return links;
}

/// Lists the links already loaded for a channel or direct conversation.
class ConversationLinksDialog extends StatefulWidget {
  const ConversationLinksDialog({
    super.key,
    required this.title,
    required this.messages,
    this.loadMessages,
    this.onOpen,
  });

  final String title;
  final Iterable<ConversationLinkSource> messages;
  final Future<List<ConversationLinkSource>> Function()? loadMessages;
  final Future<bool> Function(String link)? onOpen;

  @override
  State<ConversationLinksDialog> createState() =>
      _ConversationLinksDialogState();
}

class _ConversationLinksDialogState extends State<ConversationLinksDialog> {
  late List<ConversationLinkSource> _messages = widget.messages.toList();
  late bool _loading = widget.loadMessages != null;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final load = widget.loadMessages;
    if (load == null) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final messages = await load();
      if (mounted) setState(() => _messages = messages);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(BuildContext context, String link) async {
    final opened = await (widget.onOpen?.call(link) ?? openMessageLink(link));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final links = buildConversationLinks(_messages);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadFailed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Couldn't load links."),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            : links.isEmpty
            ? const Text('No links shared in this conversation yet.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: links.length,
                separatorBuilder: (_, _) => Divider(color: colors.divider),
                itemBuilder: (context, index) {
                  final link = links[index];
                  final details = [
                    if (link.author.trim().isNotEmpty) link.author.trim(),
                    if (link.sharedAt != null)
                      _sharedAtLabel(context, link.sharedAt!),
                  ].join(' · ');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.link, color: colors.primary),
                    title: Text(
                      link.uri.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: details.isEmpty ? null : Text(details),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () => _open(context, link.uri.toString()),
                  );
                },
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

String _sharedAtLabel(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final day = date == today
      ? 'Today'
      : date == today.subtract(const Duration(days: 1))
      ? 'Yesterday'
      : '${local.year}-${local.month.toString().padLeft(2, '0')}-'
            '${local.day.toString().padLeft(2, '0')}';
  return '$day at ${TimeOfDay.fromDateTime(local).format(context)}';
}
