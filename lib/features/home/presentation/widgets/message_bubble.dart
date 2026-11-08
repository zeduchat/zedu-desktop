import 'package:zedu/core/core.dart';

class MessageBubble extends StatefulWidget {
  final String author;
  final String text;
  final String timestamp;
  final bool isSystem;

  const MessageBubble({
    super.key,
    required this.author,
    required this.text,
    required this.timestamp,
    this.isSystem = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final Map<String, int> _reactions = {};
  bool _isHovering = false;

  void _addReaction(String emoji) {
    setState(() {
      _reactions[emoji] = (_reactions[emoji] ?? 0) + 1;
    });
  }

  void _toggleReaction(String emoji) {
    setState(() {
      if (_reactions.containsKey(emoji)) {
        if (_reactions[emoji]! > 1) {
          _reactions[emoji] = _reactions[emoji]! - 1;
        } else {
          _reactions.remove(emoji);
        }
      } else {
        _reactions[emoji] = 1;
      }
    });
  }

  /// Opens the reaction menu next to the button that was tapped, measured
  /// from its render box, instead of at a fixed spot on screen (#166).
  Future<void> _openReactionMenu(BuildContext buttonContext) async {
    final button = buttonContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final emoji = await showMenu<String>(
      context: buttonContext,
      position: position,
      items: const [
        PopupMenuItem(value: '👍', child: Text('👍')),
        PopupMenuItem(value: '❤️', child: Text('❤️')),
        PopupMenuItem(value: '😂', child: Text('😂')),
        PopupMenuItem(value: '🎉', child: Text('🎉')),
        PopupMenuItem(value: '👎', child: Text('👎')),
      ],
    );
    if (!mounted) return;
    if (emoji != null) {
      _addReaction(emoji);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial = avatarInitial(widget.author);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.isSystem
                  ? colors.textHint.withValues(alpha: 0.1)
                  : colors.primary.withValues(alpha: 0.1),
              child: Text(
                initial,
                style: TextStyle(
                  color: widget.isSystem ? colors.textHint : colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.author,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.timestamp,
                        style: TextStyle(fontSize: 11, color: colors.textHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _MessageBody(text: widget.text),
                  if (_reactions.isNotEmpty || _isHovering)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        children: [
                          ..._reactions.entries.map((e) {
                            return InkWell(
                              onTap: () => _toggleReaction(e.key),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: colors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      e.key,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${e.value}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (_isHovering)
                            Builder(
                              builder: (buttonContext) => InkWell(
                                onTap: () => _openReactionMenu(buttonContext),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.background,
                                    border: Border.all(color: colors.divider),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.add_reaction_outlined,
                                    size: 14,
                                    color: colors.textHint,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  final String text;

  const _MessageBody({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (text.contains('[Voice Note Attached]')) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill, color: colors.primary, size: 28),
            const SizedBox(width: 8),
            Container(
              height: 20,
              width: 100,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/pngs/waveform_mock.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    colors.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '0:05',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final attachmentRegex = RegExp(r'\[Attachment: (.*?)\]');
    final matches = attachmentRegex.allMatches(text);
    final cleanText = text.replaceAll(attachmentRegex, '').trim();

    Widget markdownWidget = cleanText.isNotEmpty
        ? MarkdownWithCodeBlocks(
            data: cleanText,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(fontSize: 14, color: colors.textPrimary),
              strong: TextStyle(
                fontSize: 14,
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              em: TextStyle(
                fontSize: 14,
                color: colors.textPrimary,
                fontStyle: FontStyle.italic,
              ),
              code: TextStyle(
                fontSize: 13,
                color: colors.primary,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                fontFamily: 'monospace',
              ),
            ),
            onTapLink: (href) {
              if (href != null) openMessageLink(href);
            },
          )
        : const SizedBox.shrink();

    if (matches.isNotEmpty) {
      final attachments = matches.map((m) => m.group(1)!).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cleanText.isNotEmpty) markdownWidget,
          if (cleanText.isNotEmpty) const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attachments.map((fileName) {
              final lowerName = fileName.toLowerCase();
              final isImage =
                  lowerName.endsWith('.png') ||
                  lowerName.endsWith('.jpg') ||
                  lowerName.endsWith('.jpeg') ||
                  lowerName.endsWith('.gif');
              final isVideo =
                  lowerName.endsWith('.mp4') ||
                  lowerName.endsWith('.mov') ||
                  lowerName.endsWith('.avi');

              return Container(
                width: isImage || isVideo ? 200 : 180,
                padding: isImage || isVideo
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border.all(color: colors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isImage || isVideo
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                isImage ? Icons.image : Icons.videocam,
                                color: colors.primary.withValues(alpha: 0.5),
                                size: 48,
                              ),
                            ),
                          ),
                          if (isVideo)
                            const Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 40,
                            ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: Text(
                                fileName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.insert_drive_file, color: colors.textHint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              );
            }).toList(),
          ),
        ],
      );
    }

    return markdownWidget;
  }
}
