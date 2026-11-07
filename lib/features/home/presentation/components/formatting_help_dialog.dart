import 'package:zedu/core/core.dart';

class _FormattingItem {
  const _FormattingItem({
    required this.style,
    required this.syntax,
    required this.example,
    this.isBold = false,
    this.isItalic = false,
    this.isStrikeThrough = false,
    this.isCode = false,
    this.isLink = false,
    this.isQuote = false,
  });

  final String style;
  final String syntax;
  final String example;
  final bool isBold;
  final bool isItalic;
  final bool isStrikeThrough;
  final bool isCode;
  final bool isLink;
  final bool isQuote;
}

/// Displays formatting cheat sheet for markdown options supported by the message composer.
class FormattingHelpDialog extends StatelessWidget {
  const FormattingHelpDialog({super.key});

  static const List<_FormattingItem> _items = [
    _FormattingItem(
      style: 'Bold',
      syntax: '**text**',
      example: 'bold text',
      isBold: true,
    ),
    _FormattingItem(
      style: 'Italic',
      syntax: '*text*',
      example: 'italic text',
      isItalic: true,
    ),
    _FormattingItem(
      style: 'Strikethrough',
      syntax: '~~text~~',
      example: 'strikethrough text',
      isStrikeThrough: true,
    ),
    _FormattingItem(
      style: 'Link',
      syntax: '[text](url)',
      example: 'link text',
      isLink: true,
    ),
    _FormattingItem(
      style: 'Inline code',
      syntax: '`code`',
      example: 'code',
      isCode: true,
    ),
    _FormattingItem(
      style: 'Code block',
      syntax: '```code```',
      example: 'code block',
      isCode: true,
    ),
    _FormattingItem(
      style: 'Quote',
      syntax: '> quote',
      example: 'quote text',
      isQuote: true,
    ),
    _FormattingItem(style: 'Bullet list', syntax: '- item', example: '• item'),
    _FormattingItem(
      style: 'Numbered list',
      syntax: '1. item',
      example: '1. item',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
      },
      child: Dialog(
        key: const Key('formatting_help_dialog'),
        backgroundColor: colors.background,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.divider),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Formatting help',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('formatting_help_close_button'),
                      tooltip: 'Close',
                      icon: Icon(Icons.close, color: colors.textHint, size: 20),
                      onPressed: () => Navigator.of(context).maybePop(),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.divider),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Type these markdown shortcuts directly in your message box:',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(1.4),
                          2: FlexColumnWidth(1.2),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: colors.divider,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            children: [
                              _buildHeaderCell('Style', colors),
                              _buildHeaderCell('How to type', colors),
                              _buildHeaderCell('Result', colors),
                            ],
                          ),
                          for (final item in _items)
                            TableRow(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: colors.divider.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    item.style,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 4,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.divider.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: colors.divider.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      item.syntax,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: colors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: _buildResultPreview(item, colors),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textHint,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildResultPreview(_FormattingItem item, AppPalette colors) {
    TextStyle style = TextStyle(color: colors.textPrimary, fontSize: 13);

    if (item.isBold) {
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    if (item.isItalic) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (item.isStrikeThrough) {
      style = style.copyWith(decoration: TextDecoration.lineThrough);
    }
    if (item.isLink) {
      style = style.copyWith(
        color: colors.primary,
        decoration: TextDecoration.underline,
      );
    }
    if (item.isCode) {
      style = style.copyWith(fontFamily: 'monospace', fontSize: 12);
    }

    if (item.isQuote) {
      return Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.primary, width: 3)),
        ),
        padding: const EdgeInsets.only(left: 6),
        child: Text(
          item.example,
          style: style.copyWith(
            fontStyle: FontStyle.italic,
            color: colors.textSecondary,
          ),
        ),
      );
    }

    return Text(item.example, style: style);
  }
}

/// Helper function to open the formatting help popover/dialog.
Future<void> showFormattingHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const FormattingHelpDialog(),
  );
}
