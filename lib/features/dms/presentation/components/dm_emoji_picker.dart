import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class DmEmojiPicker extends ConsumerStatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onClose;

  const DmEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onClose,
  });

  @override
  ConsumerState<DmEmojiPicker> createState() => _DmEmojiPickerState();
}

class _DmEmojiPickerState extends ConsumerState<DmEmojiPicker> {
  final _focusNode = FocusNode();
  final _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  int _selectedIndex = 0;
  List<String> _visibleEmojis = _emojis;
  bool _hasFocus = false;
  double _rowExtent = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  /// Filters the grid to the emojis whose name or keywords start with every
  /// word of [query]. An empty query shows the full grid (Ziki #3444).
  void _onQueryChanged(String query) {
    final terms = query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((term) => term.isEmpty);
    setState(() {
      _visibleEmojis = terms.isEmpty
          ? _emojis
          : [
              for (final emoji in _emojis)
                if (_matches(emoji, terms)) emoji,
            ];
      _selectedIndex = 0;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  static bool _matches(String emoji, List<String> terms) {
    final words = (_emojiKeywords[emoji] ?? '').split(' ');
    return terms.every((term) => words.any((word) => word.startsWith(term)));
  }

  /// Remembers [emoji] for the Recently used row, then reports it.
  void _select(String emoji) {
    ref.read(recentEmojisProvider.notifier).add(emoji);
    widget.onEmojiSelected(emoji);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    // Space types into the search field, so it only picks from the grid.
    final picks =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        (key == LogicalKeyboardKey.space && !_searchFocusNode.hasFocus);
    if (picks) {
      if (_visibleEmojis.isNotEmpty) _select(_visibleEmojis[_selectedIndex]);
      return KeyEventResult.handled;
    }

    final nextIndex = switch (key) {
      LogicalKeyboardKey.arrowLeft => _selectedIndex - 1,
      LogicalKeyboardKey.arrowRight => _selectedIndex + 1,
      LogicalKeyboardKey.arrowUp => _selectedIndex - 8,
      LogicalKeyboardKey.arrowDown => _selectedIndex + 8,
      _ => _selectedIndex,
    };
    if (nextIndex == _selectedIndex) return KeyEventResult.ignored;
    if (nextIndex >= 0 && nextIndex < _visibleEmojis.length) {
      setState(() => _selectedIndex = nextIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSelectedRow());
    }
    return KeyEventResult.handled;
  }

  void _showSelectedRow() {
    if (!mounted || !_scrollController.hasClients || _rowExtent == 0) return;
    final position = _scrollController.position;
    final top = (_selectedIndex ~/ 8) * _rowExtent;
    final bottom = top + _rowExtent;
    final offset = position.pixels;
    if (top < offset) {
      _scrollController.jumpTo(top.clamp(0.0, position.maxScrollExtent));
    } else if (bottom > offset + position.viewportDimension) {
      _scrollController.jumpTo(
        (bottom - position.viewportDimension).clamp(
          0.0,
          position.maxScrollExtent,
        ),
      );
    }
  }

  // Keep the existing emoji order for mouse and keyboard selection.
  static const _emojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😅',
    '😂',
    '🤣',
    '😊',
    '😇',
    '🙂',
    '😉',
    '😍',
    '🥰',
    '😘',
    '😗',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '😮',
    '😯',
    '😲',
    '😳',
    '🥺',
    '😢',
    '😭',
    '😤',
    '👍',
    '👎',
    '👌',
    '✌️',
    '🤞',
    '🤟',
    '🤙',
    '👏',
    '🙌',
    '🤝',
    '🙏',
    '💪',
    '🫡',
    '🫶',
    '👀',
    '🧠',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🔥',
    '✨',
    '🎉',
    '🎊',
    '💯',
    '💥',
    '💫',
    '🚀',
    '💻',
    '📱',
    '💼',
    '📎',
    '📌',
    '🗂️',
    '✅',
    '❌',
  ];

  // Common names and keywords for each emoji, used by the search field.
  static const _emojiKeywords = {
    '😀': 'grinning face smile happy',
    '😃': 'grinning face big eyes smile happy',
    '😄': 'grinning face smiling eyes smile happy laugh',
    '😁': 'beaming face grin smile happy',
    '😅': 'grinning face sweat smile relief nervous',
    '😂': 'face tears joy laugh lol funny',
    '🤣': 'rolling floor laughing laugh rofl lol funny',
    '😊': 'smiling face blush happy',
    '😇': 'smiling face halo angel innocent',
    '🙂': 'slightly smiling face smile',
    '😉': 'winking face wink',
    '😍': 'smiling face heart eyes love',
    '🥰': 'smiling face hearts love adore',
    '😘': 'face blowing kiss love',
    '😗': 'kissing face kiss',
    '😋': 'face savoring food yum delicious tongue',
    '😛': 'face tongue playful',
    '😜': 'winking face tongue playful crazy',
    '🤪': 'zany face crazy wild goofy',
    '😝': 'squinting face tongue playful',
    '🤑': 'money mouth face rich cash',
    '🤗': 'hugging face hug',
    '🤭': 'face hand over mouth giggle oops',
    '🤫': 'shushing face quiet secret',
    '🤔': 'thinking face think hmm',
    '😐': 'neutral face meh',
    '😑': 'expressionless face blank meh',
    '😶': 'face without mouth silent speechless',
    '😏': 'smirking face smirk',
    '😒': 'unamused face annoyed',
    '🙄': 'face rolling eyes eyeroll annoyed',
    '😬': 'grimacing face awkward cringe',
    '😮': 'face open mouth surprised wow',
    '😯': 'hushed face surprised',
    '😲': 'astonished face shocked surprised wow',
    '😳': 'flushed face embarrassed blush',
    '🥺': 'pleading face puppy eyes please',
    '😢': 'crying face tear sad',
    '😭': 'loudly crying face sob sad tears',
    '😤': 'face steam nose triumph frustrated angry',
    '👍': 'thumbs up like yes approve ok',
    '👎': 'thumbs down dislike no',
    '👌': 'ok hand perfect okay',
    '✌️': 'victory hand peace',
    '🤞': 'crossed fingers luck hope',
    '🤟': 'love you gesture hand',
    '🤙': 'call me hand shaka',
    '👏': 'clapping hands clap applause bravo',
    '🙌': 'raising hands celebrate hooray',
    '🤝': 'handshake deal agreement',
    '🙏': 'folded hands pray please thanks',
    '💪': 'flexed biceps muscle strong',
    '🫡': 'saluting face salute respect',
    '🫶': 'heart hands love',
    '👀': 'eyes look see watching',
    '🧠': 'brain smart think',
    '❤️': 'red heart love',
    '🧡': 'orange heart love',
    '💛': 'yellow heart love',
    '💚': 'green heart love',
    '💙': 'blue heart love',
    '💜': 'purple heart love',
    '🖤': 'black heart love',
    '🤍': 'white heart love',
    '🔥': 'fire flame hot lit',
    '✨': 'sparkles shiny magic',
    '🎉': 'party popper tada celebrate congratulations',
    '🎊': 'confetti ball celebrate party',
    '💯': 'hundred points perfect score',
    '💥': 'collision boom bang',
    '💫': 'dizzy star',
    '🚀': 'rocket launch ship fast',
    '💻': 'laptop computer',
    '📱': 'mobile phone smartphone',
    '💼': 'briefcase work business',
    '📎': 'paperclip attachment',
    '📌': 'pushpin pin',
    '🗂️': 'card index dividers folder files',
    '✅': 'check mark button done yes',
    '❌': 'cross mark no wrong cancel',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final recent = ref.watch(recentEmojisProvider);
    final isSearching = _searchController.text.trim().isNotEmpty;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onFocusChange: (focused) {
        if (mounted) setState(() => _hasFocus = focused);
      },
      onKeyEvent: _onKeyEvent,
      child: Container(
        width: 340,
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
              child: Row(
                children: [
                  Text(
                    'Emoji',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close, size: 16, color: colors.textHint),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _EmojiSearchField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onQueryChanged,
              ),
            ),
            Divider(height: 1, color: colors.divider),
            if (recent.isNotEmpty && !isSearching) ...[
              _RecentEmojiRow(emojis: recent, onSelected: _select),
              Divider(height: 1, color: colors.divider),
            ],
            if (_visibleEmojis.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No emoji found',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textHint,
                  ),
                ),
              )
            else
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _rowExtent = (constraints.maxWidth - 16 - 7 * 4) / 8 + 4;
                    return GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      shrinkWrap: true,
                      itemCount: _visibleEmojis.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                      itemBuilder: (context, index) {
                        final emoji = _visibleEmojis[index];
                        final isSelected = _hasFocus && index == _selectedIndex;
                        return Semantics(
                          label: emoji,
                          button: true,
                          selected: isSelected,
                          excludeSemantics: true,
                          onTap: () => _select(emoji),
                          child: InkWell(
                            onTap: () => _select(emoji),
                            canRequestFocus: false,
                            borderRadius: BorderRadius.circular(6),
                            hoverColor: colors.onPrimary.withValues(
                              alpha: 0.08,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: isSelected
                                    ? Border.all(
                                        color: colors.primary,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The compact search field at the top of the picker (Ziki #3444).
class _EmojiSearchField extends StatelessWidget {
  const _EmojiSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyle = context.textTheme.bodySmall;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );

    return SizedBox(
      height: 32,
      child: TextField(
        key: const ValueKey('emoji-search-field'),
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: textStyle?.copyWith(color: colors.textPrimary),
        cursorColor: colors.primary,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search emoji',
          hintStyle: textStyle?.copyWith(color: colors.textHint),
          prefixIcon: Icon(Icons.search, size: 16, color: colors.textHint),
          prefixIconConstraints: const BoxConstraints(minWidth: 32),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          filled: true,
          fillColor: colors.background,
          enabledBorder: border(colors.borderOutline),
          focusedBorder: border(colors.primary),
        ),
      ),
    );
  }
}

/// The emojis picked most recently this session, newest first (Ziki #3433).
class _RecentEmojiRow extends StatelessWidget {
  const _RecentEmojiRow({required this.emojis, required this.onSelected});

  final List<String> emojis;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Recently used',
              style: TextStyle(
                color: colors.textHint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              for (final emoji in emojis)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: 'Recently used $emoji',
                    excludeFromSemantics: true,
                    child: Semantics(
                      // Its own node, so it isn't merged into the picker's.
                      container: true,
                      label: 'Recently used $emoji',
                      button: true,
                      excludeSemantics: true,
                      onTap: () => onSelected(emoji),
                      child: InkWell(
                        key: ValueKey('recent-emoji-$emoji'),
                        onTap: () => onSelected(emoji),
                        canRequestFocus: false,
                        borderRadius: BorderRadius.circular(6),
                        hoverColor: colors.onPrimary.withValues(alpha: 0.08),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
