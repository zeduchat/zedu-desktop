import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Search, File Type, Date Modified and Sort above the Files lists.
class FilesToolbar extends ConsumerWidget {
  const FilesToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filesProvider);
    final notifier = ref.read(filesProvider.notifier);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilesSearchField(
                value: state.search,
                onChanged: notifier.setSearch,
              ),
              FilesDropdown<FileCategory>(
                placeholder: 'File Type',
                value: state.category,
                options: FileCategory.values,
                labelOf: (c) => c.label,
                onChanged: notifier.setCategory,
              ),
              FilesDropdown<DateModifiedFilter>(
                placeholder: 'Date Modified',
                value: state.dateModified,
                options: DateModifiedFilter.values,
                labelOf: (d) => d.label,
                onChanged: notifier.setDateModified,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilesDropdown<FilesSort>(
          placeholder: 'Sort',
          value: state.sort,
          options: FilesSort.values,
          labelOf: (s) => s.label,
          showsValue: false,
          allowsClear: false,
          onChanged: (sort) {
            if (sort != null) notifier.setSort(sort);
          },
        ),
      ],
    );
  }
}

/// Search box that reports what was typed once typing pauses, and follows
/// [value] when the search changes from elsewhere.
class FilesSearchField extends StatefulWidget {
  const FilesSearchField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<FilesSearchField> createState() => _FilesSearchFieldState();
}

class _FilesSearchFieldState extends State<FilesSearchField> {
  late final _controller = TextEditingController(text: widget.value);
  late String _lastReported = widget.value;
  Timer? _debounce;

  @override
  void didUpdateWidget(FilesSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // [value] catching up with what was typed must not disturb further typing.
    if (widget.value == oldWidget.value || widget.value == _lastReported) {
      return;
    }
    _debounce?.cancel();
    _lastReported = widget.value;
    _controller.text = widget.value;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _report(String value) {
    _lastReported = value;
    widget.onChanged(value);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _report(value));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 280,
      height: 40,
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        onSubmitted: (value) {
          _debounce?.cancel();
          _report(value);
        },
        style: context.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search by file name',
          hintStyle: context.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: colors.textHint,
          ),
          prefixIcon: Icon(Icons.search, color: colors.textHint, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colors.primary),
          ),
        ),
      ),
    );
  }
}

/// An outlined button that opens a menu of [options]. With [allowsClear]
/// the menu starts with an entry that clears the choice.
class FilesDropdown<T> extends StatelessWidget {
  const FilesDropdown({
    super.key,
    required this.placeholder,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.showsValue = true,
    this.allowsClear = true,
  });

  final String placeholder;
  final T? value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  /// Whether the button shows the chosen option instead of [placeholder].
  final bool showsValue;
  final bool allowsClear;

  static const _clear = -1;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = value;
    final label = showsValue && current != null
        ? labelOf(current)
        : placeholder;
    final isActive = showsValue && current != null;

    return PopupMenuButton<int>(
      tooltip: placeholder,
      position: PopupMenuPosition.under,
      color: colors.onPrimary,
      onSelected: (index) => onChanged(index == _clear ? null : options[index]),
      itemBuilder: (context) => [
        if (allowsClear)
          PopupMenuItem(
            value: _clear,
            child: Text(
              'Any ${placeholder.toLowerCase()}',
              style: context.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
          ),
        for (var i = 0; i < options.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    labelOf(options[i]),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (options[i] == current)
                  Icon(Icons.check, size: 18, color: colors.primary),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? colors.primaryBg : null,
          border: Border.all(
            color: isActive ? colors.borderOutline : colors.divider,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: isActive ? colors.primary : colors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isActive ? colors.primary : colors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
