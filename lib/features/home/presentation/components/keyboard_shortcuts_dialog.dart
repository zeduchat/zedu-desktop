import 'package:zedu/core/core.dart';

class _Shortcut {
  const _Shortcut(this.keys, this.description);

  final List<String> keys;
  final String description;
}

/// Lists the keyboard shortcuts the app supports, grouped by where they work.
/// Keep this in step with the key handlers: `QuickSwitcherShortcut`,
/// `QuickSwitcherDialog`, `DmMessageComposer` and `MessageComposer`.
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static Map<String, List<_Shortcut>> _sections(String modifier) => {
    'Anywhere': [
      _Shortcut([modifier, 'K'], 'Jump to a channel or conversation'),
      _Shortcut([modifier, '/'], 'Show keyboard shortcuts'),
    ],
    'Jumping to a conversation': const [
      _Shortcut(['Up', 'Down'], 'Move through the results'),
      _Shortcut(['Enter'], 'Open the highlighted result'),
      _Shortcut(['Esc'], 'Close'),
    ],
    'Direct messages': [
      const _Shortcut(['Enter'], 'Send'),
      const _Shortcut(['Shift', 'Enter'], 'New line'),
      _Shortcut([modifier, 'B'], 'Bold'),
      _Shortcut([modifier, 'I'], 'Italic'),
      const _Shortcut(['Up'], 'Edit your last message, when the box is empty'),
      const _Shortcut(['Esc'], 'Cancel editing'),
    ],
    'Channels and group chats': [
      _Shortcut([modifier, 'Enter'], 'Send'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? 'Cmd'
        : 'Ctrl';

    return Dialog(
      backgroundColor: colors.background,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Keyboard shortcuts',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: Icon(Icons.close, color: colors.textHint),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.divider),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final section in _sections(modifier).entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 6),
                        child: Text(
                          section.key,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final shortcut in section.value)
                        _ShortcutRow(shortcut: shortcut),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.shortcut});

  final _Shortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              shortcut.description,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          for (final key in shortcut.keys)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: colors.divider),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                key,
                style: TextStyle(color: colors.textPrimary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
