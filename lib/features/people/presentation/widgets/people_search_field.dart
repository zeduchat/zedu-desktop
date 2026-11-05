import 'dart:async';

import 'package:zedu/core/core.dart';

/// A search box that reports what was typed once typing pauses, like the
/// web app's 300 ms debounce. [onDark] styles it for the purple sidebar.
class PeopleSearchField extends StatefulWidget {
  const PeopleSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.onDark = false,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final bool onDark;

  @override
  State<PeopleSearchField> createState() => _PeopleSearchFieldState();
}

class _PeopleSearchFieldState extends State<PeopleSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _report(String value, {bool now = false}) {
    _debounce?.cancel();
    if (now) {
      widget.onChanged(value);
    } else {
      _debounce = Timer(
        const Duration(milliseconds: 300),
        () => widget.onChanged(value),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = widget.onDark ? colors.onPrimary : colors.textPrimary;
    final hint = widget.onDark
        ? colors.onPrimary.withValues(alpha: 0.8)
        : colors.textHint;
    final border = widget.onDark
        ? colors.onPrimary.withValues(alpha: 0.24)
        : colors.divider;

    return SizedBox(
      height: 40,
      child: TextField(
        controller: _controller,
        onChanged: _report,
        onSubmitted: (value) => _report(value, now: true),
        cursorColor: foreground,
        style: context.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: foreground,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: context.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: hint,
          ),
          filled: widget.onDark,
          fillColor: colors.onPrimary.withValues(alpha: 0.08),
          prefixIcon: Icon(Icons.search, color: hint, size: 18),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close, color: hint, size: 16),
                  onPressed: () {
                    _controller.clear();
                    _report('', now: true);
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
              color: widget.onDark ? colors.onPrimary : colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
