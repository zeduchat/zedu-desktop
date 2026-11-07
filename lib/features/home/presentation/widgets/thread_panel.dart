import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The replies to one DM message, loaded from and posted to the server.
class ThreadPanel extends ConsumerStatefulWidget {
  final String channelId;
  final String threadId;
  final String parentMessage;
  final String parentAuthor;
  final String parentTimestamp;
  final VoidCallback onClose;

  const ThreadPanel({
    super.key,
    required this.channelId,
    required this.threadId,
    required this.parentMessage,
    required this.parentAuthor,
    this.parentTimestamp = '',
    required this.onClose,
  });

  @override
  ConsumerState<ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends ConsumerState<ThreadPanel> {
  List<ThreadReply> _replies = [];
  final TextEditingController _replyController = TextEditingController();
  bool _loading = true;
  bool _loadFailed = false;
  bool _sending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final rows = await ref
          .read(dmRepositoryProvider)
          .getThreadReplies(
            channelId: widget.channelId,
            threadId: widget.threadId,
          );
      if (!mounted) return;
      setState(() {
        _replies = ThreadReply.listFrom(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _submitReply() async {
    final reply = _replyController.text.trim();
    if (reply.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await ref
          .read(dmRepositoryProvider)
          .replyToThread(
            channelId: widget.channelId,
            threadId: widget.threadId,
            content: reply,
          );
      if (!mounted) return;
      _replyController.clear();
      setState(() => _sending = false);
      // Show the reply as the server stored it, with its time and author.
      await _loadReplies();
    } catch (_) {
      if (!mounted) return;
      // Keep the typed reply so it can be sent again.
      setState(() {
        _sending = false;
        _sendError = "Couldn't send your reply. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(left: BorderSide(color: colors.divider)),
      ),
      child: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Thread',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close, color: colors.textHint),
                  splashRadius: 20,
                  tooltip: 'Close thread',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MessageBubble(
                  author: widget.parentAuthor,
                  text: widget.parentMessage,
                  timestamp: widget.parentTimestamp,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: colors.divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _loading
                              ? 'Loading replies…'
                              : _replies.length == 1
                              ? '1 reply'
                              : '${_replies.length} replies',
                          style: TextStyle(
                            color: colors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: colors.divider)),
                    ],
                  ),
                ),
                if (_loadFailed)
                  Column(
                    children: [
                      Text(
                        "Couldn't load replies.",
                        style: TextStyle(color: colors.textHint),
                      ),
                      TextButton(
                        onPressed: _loadReplies,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ..._replies.map(
                  (reply) => MessageBubble(
                    author: reply.author,
                    text: reply.text,
                    timestamp: reply.timeLabel,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_sendError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _sendError!,
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ),
                TextField(
                  controller: _replyController,
                  enabled: !_sending,
                  decoration: InputDecoration(
                    hintText: 'Reply...',
                    hintStyle: TextStyle(color: colors.textHint),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Send reply',
                      onPressed: _sending ? null : _submitReply,
                      icon: Icon(Icons.send, color: colors.primary),
                    ),
                  ),
                  onSubmitted: (_) => _submitReply(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One reply as the thread endpoint returns it.
class ThreadReply {
  final String id;
  final String author;
  final String text;
  final DateTime? sentAt;

  const ThreadReply({
    required this.id,
    required this.author,
    required this.text,
    this.sentAt,
  });

  /// Oldest first, skipping rows without text.
  static List<ThreadReply> listFrom(List<Map<String, dynamic>> rows) {
    final replies = [
      for (final row in rows)
        ThreadReply(
          id: row['id']?.toString() ?? '',
          author: _firstNonEmpty([row['username'], row['email']]) ?? 'Unknown',
          text: htmlMessageToMarkdown(
            _firstNonEmpty([row['content'], row['message']]) ?? '',
          ).trim(),
          sentAt: DateTime.tryParse(
            row['created_at']?.toString() ?? '',
          )?.toLocal(),
        ),
    ].where((reply) => reply.text.isNotEmpty).toList();
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    replies.sort((a, b) => (a.sentAt ?? epoch).compareTo(b.sentAt ?? epoch));
    return replies;
  }

  static String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// "4:05 PM", or '' when the server sent no time.
  String get timeLabel {
    final at = sentAt;
    if (at == null) return '';
    final hour = at.hour > 12 ? at.hour - 12 : (at.hour == 0 ? 12 : at.hour);
    final minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${at.hour >= 12 ? 'PM' : 'AM'}';
  }
}
