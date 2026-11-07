import 'dart:async';

import 'package:audioplayers/audioplayers.dart'
    show AudioPlayer, DeviceFileSource;

import 'package:zedu/core/core.dart';
import 'package:zedu/core/utils/shortcut_manager.dart';
import 'package:zedu/features/features.dart';

import 'composer/composer.dart';

const _voiceLogTag = 'dm-voice';

class DmMessageComposer extends ConsumerStatefulWidget {
  final String recipientName;
  final String? hintText;
  final String channelId;

  /// Where the draft is saved. Defaults to [channelId].
  final String? draftKey;
  final List<DmParticipant> participants;
  final ValueChanged<String>? onSend;
  final bool isChannel;

  /// Recorder used for voice notes. Overridable so tests can avoid the
  /// platform microphone.
  final AudioRecorder? audioRecorder;

  const DmMessageComposer({
    super.key,
    required this.recipientName,
    this.hintText,
    required this.channelId,
    this.draftKey,
    this.participants = const [],
    this.onSend,
    this.isChannel = false,
    this.audioRecorder,
  });

  @override
  ConsumerState<DmMessageComposer> createState() => DmMessageComposerState();
}

class DmMessageComposerState extends ConsumerState<DmMessageComposer> {
  late final RichTextController _controller;
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  bool _showEmojiPicker = false;

  /// Whether the plus menu with the less-used actions is open.
  bool _showMoreActions = false;
  bool _isEditMode = false;
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isStarting = false;
  // File the recorder is writing to right now, so it can be removed if the
  // composer is closed while starting or recording.
  String? _activeRecordingPath;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  XFile? _voiceNote;
  AudioPlayer? _previewPlayer;
  bool _isPreviewPlaying = false;
  String? _editingMessageId;

  /// What the composer held when edit mode started: an unsent reply that edit
  /// mode must give back when it ends.
  TextEditingValue? _textBeforeEdit;

  bool _isBold = false;
  bool _isItalic = false;
  bool _isStrikethrough = false;
  bool _isCode = false;

  List<XFile> _pendingFiles = [];

  List<DmParticipant> _mentionSuggestions = [];
  String _mentionQuery = '';

  /// Draft key this composer instance is currently bound to.
  String? _draftChannelId;

  String get _draftKey => widget.draftKey ?? widget.channelId;

  Timer? _draftSaveDebounce;

  /// Last time this composer published a typing keystroke. Publishing is
  /// throttled so holding a key doesn't notify on every character.
  DateTime? _lastTypingPublish;

  /// Draft store for the current user and org. Held in a field because `ref`
  /// can't be used in [dispose], and a flush must go to the store the draft
  /// was typed against.
  late DmDraftStore _drafts;
  late final ComposerFileStore _fileStore;

  /// Set when this conversation is deleted, so closing the composer doesn't
  /// save its text back as a draft.
  bool _channelDeleted = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = widget.audioRecorder ?? AudioRecorder();
    _drafts = ref.read(dmDraftStoreProvider);
    _fileStore = ref.read(composerFileStoreProvider);
    _controller = RichTextController();
    _controller.addListener(_onTextChanged);
    _draftChannelId = _draftKey;
    _restoreDraft();
  }

  @override
  void didUpdateWidget(covariant DmMessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The same composer widget is re-bound when the user switches chats while
    // the chat area stays mounted. Flush the debounced save for the previous
    // conversation (the listener may have saved already; this is a no-op then),
    // then swap to the new conversation and restore its draft if any.
    if (oldWidget.channelId != widget.channelId ||
        oldWidget.draftKey != widget.draftKey) {
      _draftSaveDebounce?.cancel();
      final previousChannel =
          _draftChannelId ?? oldWidget.draftKey ?? oldWidget.channelId;
      final previousDrafts = _drafts;
      final wasEditing = _isEditMode;
      // Typing belongs to the previous conversation; drop it there. The
      // throttle resets so the first keystroke here publishes at once.
      _clearTypingActivity(previousChannel);

      // Edit-mode text is an already-sent message, never a draft. Otherwise
      // flush the previous conversation's text. Store and chat-history writes
      // notify providers, so they're deferred until the build has finished.
      if (wasEditing) {
        final previousHistory = ref.read(
          chatHistoryProvider(oldWidget.channelId),
        );
        Future.microtask(previousHistory.cancelEditing);
      } else {
        final previousText = _controller.text;
        Future.microtask(
          () => previousDrafts.save(previousChannel, previousText),
        );
      }
      _drafts = ref.read(dmDraftStoreProvider);
      _draftChannelId = _draftKey;
      _channelDeleted = false;

      setState(() {
        _pendingFiles = [];
        _showEmojiPicker = false;
        _isEditMode = false;
        _editingMessageId = null;
        _textBeforeEdit = null;
      });
      _controller.clear();
      _restoreDraft();
    }
  }

  @override
  void dispose() {
    // Flush any un-debounced text. The debounced save normally covers this;
    // the write is deferred because the store notifies providers, which isn't
    // allowed while the tree is unmounting.
    _draftSaveDebounce?.cancel();
    // Best effort: the entry expires on its own if the read below can't run.
    _clearTypingActivity(widget.channelId);
    if (!_isEditMode &&
        !_channelDeleted &&
        _controller.text.trim().isNotEmpty) {
      final drafts = _drafts;
      final draftKey = _draftChannelId ?? _draftKey;
      final text = _controller.text;
      Future.microtask(() => drafts.save(draftKey, text));
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _previewPlayer?.dispose();
    _deleteRecording(_voiceNote?.path);
    if (_isRecording || _isStarting) {
      final path = _activeRecordingPath;
      _audioRecorder
          .stop()
          .then((stopped) async {
            await _deleteOwnRecording(stopped);
            await _deleteOwnRecording(path);
          })
          .catchError((_) {})
          .whenComplete(_audioRecorder.dispose);
    } else {
      _audioRecorder.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final entry = await _drafts.load(_draftKey);
    if (!mounted) return;
    if (entry == null || _controller.text.isNotEmpty) return;

    _controller.value = TextEditingValue(
      text: entry.text,
      selection: TextSelection.collapsed(offset: entry.text.length),
    );
  }

  void _onTextChanged() {
    _updateFormattingState();
    _updateMentionSuggestions();
    if (mounted) setState(() {});

    if (_isEditMode) return;

    final text = _controller.text;
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _drafts.save(_draftKey, text);
    });
    _publishTypingActivity();
  }

  /// The signed-in user's id, or null when auth isn't available (e.g. a
  /// widget test pumping the composer without auth set up). Typing presence
  /// is ancillary: it stays inert rather than breaking the composer.
  String? get _selfUserId {
    try {
      final id = ref.read(authNotifierProvider).user?.id;
      return id == null || id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  String? get _selfDisplayName {
    try {
      final user = ref.read(authNotifierProvider).user;
      if (user == null) return null;
      final name = '${user.firstName} ${user.lastName}'.trim();
      final display = name.isNotEmpty ? name : user.username;
      return display.isEmpty ? null : display;
    } catch (_) {
      return null;
    }
  }

  /// Tells the conversation someone is typing, throttled to one publish
  /// every 3 seconds while the box holds text. An empty box clears the
  /// entry at once; otherwise the entry expires 4 seconds after the last
  /// keystroke (see [TypingPresenceNotifier]).
  void _publishTypingActivity() {
    if (widget.channelId.isEmpty) return;
    final userId = _selfUserId;
    if (userId == null) return;
    final typing = ref.read(typingPresenceProvider(widget.channelId).notifier);
    if (_controller.text.trim().isEmpty) {
      typing.clearTyping(userId);
      _lastTypingPublish = null;
      return;
    }
    final now = DateTime.now();
    if (_lastTypingPublish != null &&
        now.difference(_lastTypingPublish!) < const Duration(seconds: 3)) {
      return;
    }
    _lastTypingPublish = now;
    final displayName = _selfDisplayName;
    if (displayName == null) return;
    typing.setTyping(userId: userId, displayName: displayName);
  }

  /// Drops this user's typing entry for [channelId] without notifying.
  void _clearTypingActivity(String channelId) {
    if (channelId.isEmpty) return;
    final userId = _selfUserId;
    if (userId == null) return;
    try {
      ref.read(typingPresenceProvider(channelId).notifier).clearTyping(userId);
    } catch (_) {
      // The presence entry expires on its own a few seconds later.
    }
    _lastTypingPublish = null;
  }

  void _updateFormattingState() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      setState(() {
        _isBold = false;
        _isItalic = false;
        _isStrikethrough = false;
        _isCode = false;
      });
      return;
    }
    final before = text.substring(0, sel.baseOffset);
    setState(() {
      _isBold = _isMarkerOpen(before, '**');
      _isItalic = _isMarkerOpen(before, '*');
      _isStrikethrough = _isMarkerOpen(before, '~~');
      _isCode = _isMarkerOpen(before, '`');
    });
  }

  static final _loneAsterisk = RegExp(r'(?<!\*)\*(?!\*)');

  /// Whether [textBefore] leaves a [marker] run open, so text typed next is
  /// inside it. A lone `*` is italic; the `*`s of `**` belong to bold.
  static bool _isMarkerOpen(String textBefore, String marker) {
    final count = marker == '*'
        ? _loneAsterisk.allMatches(textBefore).length
        : marker.allMatches(textBefore).length;
    return count.isOdd;
  }

  /// Whether [textAfter] starts with [marker] as its own token: for italic,
  /// a `*` that is not part of `**`.
  static bool _startsWithMarker(String textAfter, String marker) {
    if (marker == '*') return textAfter.startsWith(_loneAsterisk);
    return textAfter.startsWith(marker);
  }

  void _updateMentionSuggestions() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      setState(() => _mentionSuggestions = []);
      return;
    }
    final before = text.substring(0, sel.baseOffset);
    // Match an @-mention only when it appears at the start of the text or
    // after whitespace. This prevents matching email addresses like
    // "user@domain.com" while the user is typing an email.
    final atMatch = RegExp(r'(?:^|\s)@(\w*)$').firstMatch(before);
    if (atMatch == null) {
      setState(() {
        _mentionSuggestions = [];
        _mentionQuery = '';
      });
      return;
    }
    final query = atMatch.group(1)!.toLowerCase();
    _mentionQuery = query;
    final suggestions = widget.participants.where((p) {
      return p.username.toLowerCase().contains(query) ||
          p.email.toLowerCase().contains(query);
    }).toList();
    setState(() => _mentionSuggestions = suggestions);
  }

  void _insertMention(DmParticipant participant) {
    final text = _controller.text;
    final sel = _controller.selection;
    if (sel.baseOffset < 0) return;
    final before = text.substring(0, sel.baseOffset);
    final atIndex = before.lastIndexOf('@');
    if (atIndex == -1) return;
    if (before.substring(atIndex).contains(RegExp(r'\s'))) return;

    final after = text.substring(sel.baseOffset);
    final replacement = '@${participant.username} ';
    final newText = text.substring(0, atIndex) + replacement + after;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIndex + replacement.length),
    );
    setState(() => _mentionSuggestions = []);
    _focusNode.requestFocus();
  }

  /// The participants [text] @mentions, in the shape the server reads
  /// (`{type, id}`), like the web composer. Without it the server sees only
  /// the text "@name", records no mention and notifies nobody. Null when no
  /// one is mentioned, so the request leaves the field out as before.
  List<Map<String, String>>? _mentionsIn(String text) {
    final mentions = <Map<String, String>>[];
    final seen = <String>{};
    for (final participant in widget.participants) {
      final username = participant.username.trim();
      if (participant.userId.isEmpty || username.isEmpty) continue;
      // A whole @handle only: not part of an email or a longer handle.
      final handle = RegExp(
        '(?<![\\w@.])@${RegExp.escape(username)}(?![\\w.-])',
        caseSensitive: false,
      );
      if (handle.hasMatch(text) && seen.add(participant.userId)) {
        mentions.add({
          'type': participant.userType == 'bot' ? 'bot' : 'user',
          'id': participant.userId,
        });
      }
    }
    return mentions.isEmpty ? null : mentions;
  }

  void _handleSend() {
    final text = _controller.text.trim();
    final isEdit = _isEditMode && _editingMessageId != null;
    // An edit needs text; a waiting file or voice note must not let it through.
    if (isEdit && text.isEmpty) return;
    if (text.isEmpty && _pendingFiles.isEmpty && _voiceNote == null) return;
    if (widget.channelId.isEmpty) {
      _showVoiceError('Channel not loaded yet.');
      return;
    }

    if (isEdit) {
      if (widget.isChannel) {
        // A channel message is a thread: the DM edit route can't change it.
        _saveChannelEdit(_editingMessageId!, text);
      } else {
        ref
            .read(chatHistoryProvider(widget.channelId))
            .saveEdit(_editingMessageId!, text);
      }
      // An edit sends nothing new: the unsent reply and its draft come back,
      // and a waiting voice note or file is kept.
      _exitEditMode();
      _focusNode.requestFocus();
      return;
    } else {
      ref
          .read(chatHistoryProvider(widget.channelId))
          .sendMessage(
            text,
            media: [..._pendingFiles, ?_voiceNote],
            mentions: _mentionsIn(text),
            isChannel: widget.isChannel,
          );
      widget.onSend?.call(text);
    }

    // The message is out, so the draft no longer exists.
    _draftSaveDebounce?.cancel();
    _drafts.clear(_draftKey);
    // Sent text is no longer typing.
    _clearTypingActivity(widget.channelId);

    _controller.clear();
    // Saving an edit sends nothing, so a waiting voice note or file is kept.
    if (!isEdit) {
      _previewPlayer?.stop();
      setState(() {
        _pendingFiles = [];
        _voiceNote = null;
        _isPreviewPlaying = false;
      });
    }
    _focusNode.requestFocus();
  }

  /// The signed-in user's latest message in this channel, which the Up arrow
  /// edits. The channel history is newest first and only holds channel
  /// messages, which carry the thread id the edit route needs.
  ChannelMessage? _lastOwnChannelMessage() {
    final me = ref.read(chatHistoryProvider(widget.channelId)).currentUserId;
    final messages = ref.read(channelHistoryProvider(widget.channelId)).value;
    if (messages == null) return null;
    for (final message in messages) {
      if (message.userId == me &&
          message.threadId != null &&
          message.text.isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  /// Saves an edited channel message through the thread route (Ziki #3440)
  /// and reloads the channel's messages.
  Future<void> _saveChannelEdit(String threadId, String text) async {
    final channelId = widget.channelId;
    final result = await ref
        .read(channelRepositoryProvider)
        .editChannelMessage(
          channelId: channelId,
          threadId: threadId,
          content: text,
        );
    if (!mounted) return;
    switch (result) {
      case Success():
        ref.invalidate(channelHistoryProvider(channelId));
      case Failure():
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: "Couldn't edit the message. Please try again.",
        );
    }
  }

  /// Puts the given message in the composer for editing, the same way the
  /// Up-arrow shortcut does. Called from the message menu's "Edit message".
  /// Moves the cursor back into the message box, for example after the
  /// conversation search panel closes.
  void focusInput() => _focusNode.requestFocus();

  void enterEditMode(String messageId, String content) =>
      _enterEditMode(messageId, content);

  void _enterEditMode(String messageId, String content) {
    if (!_isEditMode) {
      // Keep the unsent reply, and save it now in case the debounced save
      // hasn't run yet: edit-mode text is never saved as a draft.
      _textBeforeEdit = _controller.value;
      _draftSaveDebounce?.cancel();
      _drafts.save(widget.channelId, _controller.text);
    }
    setState(() {
      _isEditMode = true;
      _editingMessageId = messageId;
      _controller.text = content;
      _controller.selection = TextSelection.collapsed(offset: content.length);
    });
    _focusNode.requestFocus();
    ref.read(chatHistoryProvider(widget.channelId)).startEditing(messageId);
  }

  void _exitEditMode() {
    final restored = _textBeforeEdit ?? TextEditingValue.empty;
    _textBeforeEdit = null;
    setState(() {
      _isEditMode = false;
      _editingMessageId = null;
    });
    _controller.value = restored;
    ref.read(chatHistoryProvider(widget.channelId)).cancelEditing();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Pass system-reserved shortcuts (Ctrl+S, Ctrl+P, Cmd+S, Cmd+P) through
    // to the operating system instead of handling them in the app.
    final modifiers = <String>{};
    if (HardwareKeyboard.instance.isControlPressed) modifiers.add('ctrl');
    if (HardwareKeyboard.instance.isShiftPressed) modifiers.add('shift');
    if (HardwareKeyboard.instance.isAltPressed) modifiers.add('alt');
    if (HardwareKeyboard.instance.isMetaPressed) modifiers.add('meta');

    if (modifiers.isNotEmpty &&
        ref
            .read(shortcutManagerProvider.notifier)
            .shouldPassToSystem(key, modifiers)) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.keyE &&
        HardwareKeyboard.instance.isShiftPressed &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) &&
        !HardwareKeyboard.instance.isAltPressed) {
      _toggleEmojiPicker();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final hasModifier =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      // Shift+Enter must fall through so the default newline is inserted.
      if (!hasModifier && HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      // Never send while an IME (Chinese, Japanese…) is still composing.
      if (_controller.value.composing.isValid &&
          !_controller.value.composing.isCollapsed) {
        return KeyEventResult.ignored;
      }
      // With the @mention list open, plain Enter picks the first suggestion
      // instead of sending the half-typed mention.
      if (!hasModifier && _mentionSuggestions.isNotEmpty) {
        _insertMention(_mentionSuggestions.first);
        return KeyEventResult.handled;
      }
      // Plain Enter, Ctrl+Enter and Cmd+Enter all share the send path, which
      // no-ops on an empty box. Handled either way, so no newline is added.
      _handleSend();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyB &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _insertBold();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyI &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _insertItalic();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_showEmojiPicker) {
        _closeEmojiPicker();
        return KeyEventResult.handled;
      }
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
        return KeyEventResult.handled;
      }
      if (_showMoreActions) {
        setState(() => _showMoreActions = false);
        return KeyEventResult.handled;
      }
      if (_isEditMode) {
        _exitEditMode();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowUp && _controller.text.isEmpty) {
      if (widget.isChannel) {
        final own = _lastOwnChannelMessage();
        if (own != null) {
          _enterEditMode(own.threadId!, own.text);
          return KeyEventResult.handled;
        }
      } else {
        final history = ref.read(chatHistoryProvider(widget.channelId));
        final lastId = history.lastSentMessageId;
        final lastContent = history.lastSentMessageContent;
        if (lastId != null && lastContent != null) {
          _enterEditMode(lastId, lastContent);
          return KeyEventResult.handled;
        }
      }
    }

    if (key == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      handlePaste();
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  // An unfocused composer has no selection; its markers still go at the end.
  TextSelection get _selectionOrEnd => _controller.selection.isValid
      ? _controller.selection
      : TextSelection.collapsed(offset: _controller.text.length);

  void _wrapSelection(String before, [String? after]) {
    after ??= before;
    final text = _controller.text;
    final sel = _selectionOrEnd;

    if (sel.isCollapsed &&
        before == after &&
        _isMarkerOpen(text.substring(0, sel.start), before)) {
      _endMarkerRun(before);
    } else if (sel.isCollapsed) {
      final insert = '$before$after';
      final newText =
          text.substring(0, sel.start) + insert + text.substring(sel.end);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + before.length),
      );
    } else {
      final selected = text.substring(sel.start, sel.end);
      final replacement = '$before$selected$after';
      final newText =
          text.substring(0, sel.start) + replacement + text.substring(sel.end);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start + before.length,
          extentOffset: sel.start + before.length + selected.length,
        ),
      );
    }
    _focusNode.requestFocus();
  }

  /// Ends the [marker] run the caret is in, so a second click on Bold (or
  /// Italic, Strikethrough, Code) turns the format off instead of inserting
  /// another, empty pair of markers.
  void _endMarkerRun(String marker) {
    final text = _controller.text;
    final caret = _controller.selection.start;
    final head = text.substring(0, caret);
    final tail = text.substring(caret);

    if (head.endsWith(marker) && _startsWithMarker(tail, marker)) {
      // Nothing typed between the markers yet: drop the empty pair.
      final start = caret - marker.length;
      _controller.value = TextEditingValue(
        text: text.substring(0, start) + tail.substring(marker.length),
        selection: TextSelection.collapsed(offset: start),
      );
    } else if (_startsWithMarker(tail, marker)) {
      // Step over the closing marker so the next text is plain.
      _controller.selection = TextSelection.collapsed(
        offset: caret + marker.length,
      );
    } else {
      // The run has no closing marker yet: close it here.
      _controller.value = TextEditingValue(
        text: head + marker + tail,
        selection: TextSelection.collapsed(offset: caret + marker.length),
      );
    }
  }

  void _insertBold() => _wrapSelection('**');
  void _insertItalic() => _wrapSelection('*');
  void _insertStrikethrough() => _wrapSelection('~~');
  void _insertCode() => _wrapSelection('`');

  void _insertLink() => _wrapSelection('[', '](url)');

  void _insertQuote() {
    final text = _controller.text;
    final sel = _selectionOrEnd;
    if (sel.isCollapsed) {
      // "> " only quotes at the start of a line, so a bare caret prefixes the
      // current line and the caret stays on the same character.
      final lineStart = sel.start == 0
          ? 0
          : text.lastIndexOf('\n', sel.start - 1) + 1;
      _controller.value = TextEditingValue(
        text: '${text.substring(0, lineStart)}> ${text.substring(lineStart)}',
        selection: TextSelection.collapsed(offset: sel.start + 2),
      );
      _focusNode.requestFocus();
      return;
    }
    final selected = text.substring(sel.start, sel.end);
    // A selection that ends right after a newline leaves an empty last piece.
    // Quoting it would put "> " on the first line that is not selected.
    final endsWithNewline = selected.endsWith('\n');
    final lines = selected.split('\n');
    final quoted =
        (endsWithNewline ? lines.sublist(0, lines.length - 1) : lines)
            .map((line) => '> $line')
            .join('\n');
    final insert = endsWithNewline ? '$quoted\n' : quoted;
    final newText =
        text.substring(0, sel.start) + insert + text.substring(sel.end);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + insert.length),
    );
    _focusNode.requestFocus();
  }

  /// Inserts a Markdown horizontal rule (`---`) on its own line at the cursor.
  ///
  /// The rule needs a blank line above it: `text\n---` is a setext heading,
  /// not a divider.
  void _insertDivider() {
    final text = _controller.text;
    final sel = _controller.selection;
    final pos = sel.isValid ? sel.end : text.length;
    final before = text.substring(0, pos);

    final String leading;
    if (before.isEmpty || before.endsWith('\n\n')) {
      leading = '';
    } else if (before.endsWith('\n')) {
      leading = '\n';
    } else {
      leading = '\n\n';
    }

    final insert = '$leading---\n';
    _controller.value = TextEditingValue(
      text: before + insert + text.substring(pos),
      selection: TextSelection.collapsed(offset: pos + insert.length),
    );
    _focusNode.requestFocus();
  }

  void _toggleMoreActions() {
    setState(() => _showMoreActions = !_showMoreActions);
  }

  /// Closes the plus menu, then runs the picked action as before.
  void _runMoreAction(VoidCallback action) {
    setState(() => _showMoreActions = false);
    action();
  }

  void _insertChannelTag() {
    final text = _controller.text;
    final sel = _controller.selection;
    final pos = sel.isValid ? sel.baseOffset : text.length;
    final newText = '${text.substring(0, pos)}#${text.substring(pos)}';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + 1),
    );
    _focusNode.requestFocus();
  }

  void _toggleEmojiPicker() {
    setState(() => _showEmojiPicker = !_showEmojiPicker);
  }

  void _closeEmojiPicker() {
    setState(() => _showEmojiPicker = false);
    _focusNode.requestFocus();
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final sel = _controller.selection;
    // A highlighted word is replaced; start and end also cover a selection
    // dragged backwards.
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _focusNode.requestFocus();
  }

  bool _isDragging = false;

  Future<void> _toggleVoiceRecording() async {
    if (_isStarting) return;
    if (_isRecording) {
      await _finishVoiceRecording();
    } else if (_voiceNote == null) {
      await _startVoiceRecording();
    }
  }

  void _showVoiceError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _startVoiceRecording() async {
    _isStarting = true;
    try {
      // Nothing shows as "recording" until the microphone is allowed.
      if (!await _audioRecorder.hasPermission()) {
        _showVoiceError('Allow microphone access to record a voice message.');
        return;
      }
      final pathResult = _fileStore.newRecordingPath();
      if (pathResult case Failure(:final error)) {
        _showVoiceError(error.message);
        return;
      }
      final path = (pathResult as Success<String>).value;
      _activeRecordingPath = path;
      await _audioRecorder.start(const RecordConfig(), path: path);
      // Only remember the file once recording really started.
      _fileStore.trackRecording(path);
      if (!mounted) {
        // dispose() is already stopping and cleaning up the recorder.
        await _deleteOwnRecording(path);
        return;
      }
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
    } catch (error, stackTrace) {
      _activeRecordingPath = null;
      if (mounted) setState(() => _isRecording = false);
      AppLogger.w(
        'Could not start the voice recording',
        tag: _voiceLogTag,
        error: error,
        stackTrace: stackTrace,
      );
      _showVoiceError(
        'Could not start recording. Check your microphone and try again.',
      );
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _finishVoiceRecording() async {
    _recordTimer?.cancel();
    try {
      final recordedPath = await _audioRecorder.stop();
      _activeRecordingPath = null;
      if (!mounted) {
        // The composer is gone, so nobody will send this recording.
        await _deleteRecording(recordedPath);
        return;
      }
      setState(() {
        _isRecording = false;
        if (recordedPath != null) {
          _voiceNote = XFile(
            recordedPath,
            name: 'voice-message-${DateTime.now().millisecondsSinceEpoch}.m4a',
            mimeType: 'audio/mp4',
          );
        }
      });
    } catch (error, stackTrace) {
      if (mounted) setState(() => _isRecording = false);
      AppLogger.w(
        'Could not save the voice recording',
        tag: _voiceLogTag,
        error: error,
        stackTrace: stackTrace,
      );
      _showVoiceError('Could not save the recording. Please try again.');
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordTimer?.cancel();
    try {
      await _deleteRecording(await _audioRecorder.stop());
    } catch (error) {
      AppLogger.d(
        'Failed to stop the cancelled voice recording: $error',
        tag: 'DmMessageComposer',
      );
    }
    _activeRecordingPath = null;
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _togglePreviewPlayback() async {
    final note = _voiceNote;
    if (note == null) return;
    try {
      final player = _previewPlayer ??= AudioPlayer()
        ..onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPreviewPlaying = false);
        });
      if (_isPreviewPlaying) {
        await player.pause();
        if (mounted) setState(() => _isPreviewPlaying = false);
      } else {
        await player.play(DeviceFileSource(note.path));
        if (mounted) setState(() => _isPreviewPlaying = true);
      }
    } catch (error, stackTrace) {
      AppLogger.w(
        'Could not play back the voice recording',
        tag: _voiceLogTag,
        error: error,
        stackTrace: stackTrace,
      );
      _showVoiceError('Could not play the recording.');
    }
  }

  Future<void> _removeVoiceNote() async {
    await _previewPlayer?.stop();
    await _deleteRecording(_voiceNote?.path);
    if (mounted) {
      setState(() {
        _voiceNote = null;
        _isPreviewPlaying = false;
      });
    }
  }

  /// Deletes a file this recorder is writing or has just written. The path
  /// always comes from the recorder itself, never from a file the user picked.
  Future<void> _deleteOwnRecording(String? path) async {
    if (path == null) return;
    _fileStore.trackRecording(path);
    await _deleteRecording(path);
  }

  /// Deletes a recording this app made. Never used on files the user picked.
  Future<void> _deleteRecording(String? path) async {
    final result = await _fileStore.deleteRecording(path);
    if (result case Failure(:final error)) {
      AppLogger.w(
        '${error.message} (recording: $path)',
        tag: 'DmMessageComposer',
      );
    }
  }

  String _formatSeconds(int total) {
    final minutes = total ~/ 60;
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildRecordingBar(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record, color: colors.error, size: 14),
          const SizedBox(width: 6),
          Text(
            _formatSeconds(_recordSeconds),
            style: TextStyle(
              color: colors.error,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recording...',
              style: TextStyle(color: colors.textHint, fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            onPressed: _cancelVoiceRecording,
            icon: Icon(Icons.close_rounded, color: colors.textHint),
          ),
          IconButton(
            tooltip: 'Stop recording',
            visualDensity: VisualDensity.compact,
            iconSize: 22,
            onPressed: _finishVoiceRecording,
            icon: Icon(Icons.stop_circle_rounded, color: colors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePreviewBar(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: 4, right: 4),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _togglePreviewPlayback,
                borderRadius: BorderRadius.circular(16),
                child: Icon(
                  _isPreviewPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatSeconds(_recordSeconds),
                style: TextStyle(color: colors.textPrimary, fontSize: 12),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _removeVoiceNote,
                borderRadius: BorderRadius.circular(16),
                child: Icon(
                  Icons.close_rounded,
                  color: colors.textHint,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> addFiles(List<XFile> newFiles) async {
    final validFiles = <XFile>[];
    for (final file in newFiles) {
      try {
        if (file.path.isNotEmpty) {
          final exists = await _fileStore.exists(file.path);
          if (exists is! Success<bool> || !exists.value) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'File ${file.name} does not exist or is invalid.',
                  ),
                ),
              );
            }
            continue;
          }
        }
        final length = await file.length();
        // The composer can be disposed (e.g. the user switched conversation)
        // while file sizes are still being read.
        if (!mounted) return;
        if (length > 20 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File ${file.name} exceeds 20MB limit.')),
            );
          }
          continue;
        }
        validFiles.add(file);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Couldn't read ${file.path.split(RegExp(r'[\\/]')).last}.",
              ),
            ),
          );
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _pendingFiles.addAll(validFiles);
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) return;
    // The paths come from the system file dialog, so there is no traversal to
    // guard against: on macOS and Linux every one of them starts with '/', and
    // a name such as `notes..v2.txt` is ordinary. `addFiles` checks that each
    // file exists and is under the size limit. The MIME type is left unset
    // because the upload works it out from the file name; `f.extension` is a
    // bare extension such as `pdf`, not a MIME type.
    final picked = result.files
        .where((PlatformFile f) => f.path != null)
        .map((PlatformFile f) => XFile(f.path!, name: f.name))
        .toList();
    await addFiles(picked);
  }

  void _removeFile(int index) {
    setState(
      () => _pendingFiles = List<XFile>.of(_pendingFiles)..removeAt(index),
    );
  }

  Future<bool> handlePaste({DataReader? reader}) async {
    final clipReader = reader ?? await SystemClipboard.instance?.read();
    if (clipReader == null) return false;

    SimpleFileFormat? matchedFormat;
    String ext = 'png';
    String mime = 'image/png';

    if (clipReader.canProvide(Formats.png)) {
      matchedFormat = Formats.png;
      ext = 'png';
      mime = 'image/png';
    } else if (clipReader.canProvide(Formats.jpeg)) {
      matchedFormat = Formats.jpeg;
      ext = 'jpg';
      mime = 'image/jpeg';
    } else if (clipReader.canProvide(Formats.webp)) {
      matchedFormat = Formats.webp;
      ext = 'webp';
      mime = 'image/webp';
    } else if (clipReader.canProvide(Formats.gif)) {
      matchedFormat = Formats.gif;
      ext = 'gif';
      mime = 'image/gif';
    }

    if (matchedFormat != null) {
      final completer = Completer<bool>();
      clipReader.getFile(
        matchedFormat,
        (file) async {
          try {
            final bytes = await file.readAll();
            if (bytes.isNotEmpty) {
              final fileName =
                  'pasted_image_${DateTime.now().millisecondsSinceEpoch}.$ext';
              try {
                final saved = await _fileStore.writeTemporaryFile(
                  fileName,
                  bytes,
                );
                switch (saved) {
                  case Success(:final value):
                    await addFiles([
                      XFile(value, name: fileName, mimeType: mime),
                    ]);
                  case Failure():
                    await addFiles([
                      XFile.fromData(bytes, name: fileName, mimeType: mime),
                    ]);
                }
              } catch (_) {
                await addFiles([
                  XFile.fromData(bytes, name: fileName, mimeType: mime),
                ]);
              }
            }
            if (!completer.isCompleted) completer.complete(true);
          } catch (_) {
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
      );
      return await completer.future;
    }

    if (clipReader.canProvide(Formats.fileUri)) {
      clipReader.getValue(Formats.fileUri, (uri) async {
        if (uri != null && uri.hasScheme && uri.scheme == 'file') {
          final filePath = uri.toFilePath();
          final fileExt = filePath.split('.').last.toLowerCase();
          if (const [
            'png',
            'jpg',
            'jpeg',
            'webp',
            'gif',
            'bmp',
          ].contains(fileExt)) {
            final exists = await _fileStore.exists(filePath);
            if (exists is Success<bool> && exists.value) {
              final fileName = XFile(filePath).name;
              await addFiles([XFile(filePath, name: fileName)]);
            }
          }
        }
      });
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasText = _controller.text.trim().isNotEmpty;
    final isEditing = _isEditMode && _editingMessageId != null;
    final hasSendableContent =
        hasText ||
        (!isEditing && (_pendingFiles.isNotEmpty || _voiceNote != null));
    // A user or org change replaces the store; follow it.
    ref.listen(dmDraftStoreProvider, (_, next) => _drafts = next);
    ref.listen(
      dmConversationActionsProvider.select(
        (actions) => actions.deletedIds.contains(widget.channelId),
      ),
      (_, deleted) {
        if (!deleted) return;
        _channelDeleted = true;
        _draftSaveDebounce?.cancel();
      },
    );

    final mainColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TypingIndicator(
          channelId: widget.channelId,
          excludeUserId: _selfUserId,
        ),
        if (_mentionSuggestions.isNotEmpty)
          MentionSuggestionList(
            suggestions: _mentionSuggestions,
            query: _mentionQuery,
            colors: colors,
            onSelect: _insertMention,
          ),

        if (_showEmojiPicker)
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: DmEmojiPicker(
                onEmojiSelected: _insertEmoji,
                onClose: _closeEmojiPicker,
              ),
            ),
          ),

        if (_isEditMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            color: colors.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(Icons.edit, size: 14, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Editing message',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _exitEditMode,
                  child: Text(
                    'Cancel (Esc)',
                    style: TextStyle(color: colors.textHint, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isEditMode ? colors.primary : colors.primary,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      ToolbarButton(
                        icon: Icons.format_bold,
                        tooltip: 'Bold (Ctrl+B)',
                        onTap: _insertBold,
                        colors: colors,
                        isActive: _isBold,
                      ),
                      ToolbarButton(
                        icon: Icons.format_italic,
                        tooltip: 'Italic (Ctrl+I)',
                        onTap: _insertItalic,
                        colors: colors,
                        isActive: _isItalic,
                      ),
                      ToolbarButton(
                        icon: Icons.strikethrough_s,
                        tooltip: 'Strikethrough',
                        onTap: _insertStrikethrough,
                        colors: colors,
                        isActive: _isStrikethrough,
                      ),
                      ToolbarButton(
                        icon: Icons.link_rounded,
                        tooltip: 'Link',
                        onTap: _insertLink,
                        colors: colors,
                      ),
                      ToolbarButton(
                        icon: Icons.code_rounded,
                        tooltip: 'Inline code',
                        onTap: _insertCode,
                        colors: colors,
                        isActive: _isCode,
                      ),
                      ToolbarButton(
                        icon: Icons.format_quote_rounded,
                        tooltip: 'Block quote',
                        onTap: _insertQuote,
                        colors: colors,
                      ),
                      const Spacer(),
                      ToolbarButton(
                        key: const Key('dm_composer_formatting_help_button'),
                        icon: Icons.help_outline_rounded,
                        tooltip: 'Formatting help',
                        onTap: () => showFormattingHelp(context),
                        colors: colors,
                      ),
                    ],
                  ),
                ),
                Divider(height: 12, color: colors.divider),
                if (_isRecording) _buildRecordingBar(colors),
                if (_voiceNote != null && !_isRecording)
                  _buildVoicePreviewBar(colors),
                if (_pendingFiles.isNotEmpty)
                  AttachmentPreviewBar(
                    files: _pendingFiles,
                    onRemove: _removeFile,
                    colors: colors,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Focus(
                    onKeyEvent: _handleKeyEvent,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 8,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _isEditMode
                            ? 'Editing message…'
                            : widget.hintText ??
                                  'Message ${widget.recipientName} · '
                                      'Enter to send, Shift+Enter for a new line',
                        hintStyle: TextStyle(
                          color: colors.textHint.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      ToolbarButton(
                        icon: Icons.emoji_emotions_outlined,
                        tooltip: 'Emoji (Ctrl/Cmd+Shift+E)',
                        onTap: _toggleEmojiPicker,
                        colors: colors,
                        isActive: _showEmojiPicker,
                      ),
                      ToolbarButton(
                        icon: Icons.alternate_email_rounded,
                        tooltip: 'Mention someone',
                        onTap: () {
                          final text = _controller.text;
                          final sel = _controller.selection;
                          final pos = sel.isValid
                              ? sel.baseOffset
                              : text.length;
                          final newText =
                              '${text.substring(0, pos)}@${text.substring(pos)}';
                          _controller.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(offset: pos + 1),
                          );
                          _focusNode.requestFocus();
                        },
                        colors: colors,
                      ),
                      const SizedBox(width: 2),
                      ToolbarButton(
                        icon: _showMoreActions ? Icons.close : Icons.add,
                        tooltip: _showMoreActions
                            ? 'Close more actions'
                            : 'More actions',
                        onTap: _toggleMoreActions,
                        colors: colors,
                        isActive: _showMoreActions,
                      ),
                      if (_showMoreActions) ...[
                        ToolbarButton(
                          icon: Icons.attach_file_rounded,
                          tooltip: 'Attach file',
                          onTap: () => _runMoreAction(_pickFiles),
                          colors: colors,
                          isActive: _pendingFiles.isNotEmpty,
                        ),
                        ToolbarButton(
                          icon: _isRecording
                              ? Icons.stop_rounded
                              : Icons.mic_none_rounded,
                          tooltip: _isRecording
                              ? 'Stop recording'
                              : 'Voice message',
                          onTap: () => _runMoreAction(_toggleVoiceRecording),
                          colors: colors,
                          isActive: _isRecording || _voiceNote != null,
                        ),
                        ToolbarButton(
                          icon: Icons.tag,
                          tooltip: 'Channel tag',
                          onTap: () => _runMoreAction(_insertChannelTag),
                          colors: colors,
                        ),
                        ToolbarButton(
                          icon: Icons.horizontal_rule_rounded,
                          tooltip: 'Divider',
                          onTap: () => _runMoreAction(_insertDivider),
                          colors: colors,
                        ),
                      ],
                      const Spacer(),
                      Tooltip(
                        message: 'Send message',
                        child: GestureDetector(
                          onTap: hasSendableContent ? _handleSend : null,
                          child: Icon(
                            Icons.send_rounded,
                            color: hasSendableContent
                                ? colors.primary
                                : colors.textHint.withValues(alpha: 0.55),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return DropTarget(
      onDragDone: (detail) {
        addFiles(detail.files);
        setState(() => _isDragging = false);
      },
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      child: Stack(
        children: [
          mainColumn,
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: colors.primary.withValues(alpha: 0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Drop files to attach',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
