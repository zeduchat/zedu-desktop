import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// A slim, muted line for an automatic channel notice such as
/// "mimi joined this channel", so it is not mistaken for a person's message
/// (Ziki #31). Named people show without the "@" and turn the primary colour
/// on hover; tapping one calls [onMentionTap].
class ChannelSystemNotice extends StatefulWidget {
  const ChannelSystemNotice({
    super.key,
    required this.message,
    this.onMentionTap,
  });

  final ChannelMessage message;

  /// Called with a named person when their name is tapped.
  final ValueChanged<ChannelNoticePart>? onMentionTap;

  @override
  State<ChannelSystemNotice> createState() => _ChannelSystemNoticeState();
}

class _ChannelSystemNoticeState extends State<ChannelSystemNotice> {
  /// One per named person, by position, kept while the line is on screen.
  final Map<int, TapGestureRecognizer> _recognizers = {};
  int? _hovered;

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = widget.message.createdAt;
    final textStyle = TextStyle(fontSize: 13, color: colors.textHint);
    final nameStyle = textStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.textSecondary,
    );

    final parts = widget.message.noticeParts;
    final spans = <InlineSpan>[
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isMention)
          _mentionSpan(i, parts[i], nameStyle, colors)
        else
          TextSpan(text: parts[i].text),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Lines up with the avatars of normal messages.
          SizedBox(
            width: 32,
            child: Icon(
              Icons.person_add_alt_1_outlined,
              size: 14,
              color: colors.textHint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(TextSpan(style: textStyle, children: spans)),
          ),
          if (time != null) ...[
            const SizedBox(width: 8),
            Text(
              TimeOfDay.fromDateTime(time).format(context),
              style: TextStyle(fontSize: 11, color: colors.textHint),
            ),
          ],
        ],
      ),
    );
  }

  TextSpan _mentionSpan(
    int index,
    ChannelNoticePart part,
    TextStyle style,
    AppPalette colors,
  ) {
    final onTap = widget.onMentionTap;
    final recognizer = onTap == null
        ? null
        : (_recognizers.putIfAbsent(index, TapGestureRecognizer.new)
            ..onTap = () => onTap(part));
    final hovered = _hovered == index;
    return TextSpan(
      text: part.text,
      style: hovered ? style.copyWith(color: colors.primary) : style,
      recognizer: recognizer,
      mouseCursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = index),
      onExit: (_) {
        if (_hovered == index) setState(() => _hovered = null);
      },
    );
  }
}
