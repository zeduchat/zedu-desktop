import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ThreadPanel extends StatefulWidget {
  final String parentMessage;
  final String parentAuthor;
  final String parentTimestamp;
  final VoidCallback onClose;

  const ThreadPanel({
    super.key,
    required this.parentMessage,
    required this.parentAuthor,
    this.parentTimestamp = '',
    required this.onClose,
  });

  @override
  State<ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends State<ThreadPanel> {
  final List<String> _replies = [];
  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _submitReply() {
    final reply = _replyController.text.trim();
    if (reply.isEmpty) return;
    setState(() => _replies.add(reply));
    _replyController.clear();
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
                          '${_replies.length} replies',
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
                ..._replies.map(
                  (reply) => MessageBubble(
                    author: 'You',
                    text: reply,
                    timestamp: '3:20 PM',
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
            child: TextField(
              controller: _replyController,
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
                  onPressed: _submitReply,
                  icon: Icon(Icons.send, color: colors.primary),
                ),
              ),
              onSubmitted: (_) => _submitReply(),
            ),
          ),
        ],
      ),
    );
  }
}
