import 'package:zedu/core/core.dart';

/// The country selector shown inside a phone number field. It shows the
/// country whose dialling code the number starts with (`NG +234`) and opens a
/// searchable list; choosing a country writes its code into [controller].
class PhoneCountryPrefix extends StatefulWidget {
  const PhoneCountryPrefix({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<PhoneCountryPrefix> createState() => _PhoneCountryPrefixState();
}

class _PhoneCountryPrefixState extends State<PhoneCountryPrefix> {
  DialCode? _selected;

  @override
  void initState() {
    super.initState();
    _selected = DialCode.match(widget.controller.text);
    widget.controller.addListener(_syncWithText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncWithText);
    super.dispose();
  }

  /// Follows a code typed into the field, but keeps a chosen country while the
  /// number still starts with its code (`+1` stays Canada once chosen).
  void _syncWithText() {
    final text = widget.controller.text.trimLeft();
    final current = _selected;
    if (current != null &&
        text.startsWith('+') &&
        text
            .substring(1)
            .replaceAll(RegExp(r'[\s\-().]'), '')
            .startsWith(current.digits)) {
      return;
    }
    final next = DialCode.match(text);
    if (next != _selected) setState(() => _selected = next);
  }

  Future<void> _pick() async {
    final picked = await showDialog<DialCode>(
      context: context,
      builder: (_) => const _DialCodePicker(),
    );
    if (picked == null || !mounted) return;
    final text = picked.applyTo(widget.controller.text);
    setState(() => _selected = picked);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'Country code',
      child: InkWell(
        key: const ValueKey('phone-country-prefix'),
        borderRadius: BorderRadius.circular(4),
        onTap: _pick,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selected?.label ?? 'Code',
                style: context.textTheme.bodyLarge?.copyWith(
                  fontFamily: FontFamily.roboto,
                  color: _selected == null
                      ? colors.textHint
                      : colors.textPrimary,
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 20, color: colors.textHint),
              const SizedBox(width: 4),
              Container(width: 1, height: 24, color: colors.borderOutline),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialCodePicker extends StatefulWidget {
  const _DialCodePicker();

  @override
  State<_DialCodePicker> createState() => _DialCodePickerState();
}

class _DialCodePickerState extends State<_DialCodePicker> {
  String _query = '';

  List<DialCode> get _matches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return kDialCodes;
    final digits = query.replaceAll(RegExp(r'\D'), '');
    return kDialCodes.where((code) {
      return code.name.toLowerCase().contains(query) ||
          code.iso.toLowerCase() == query ||
          (digits.isNotEmpty && code.digits.startsWith(digits));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final matches = _matches;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Select country code',
        style: context.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('phone-country-search'),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search country or code',
                prefixIcon: Icon(Icons.search, color: colors.textHint),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'No matching country',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final code = matches[index];
                        return ListTile(
                          dense: true,
                          title: Text(code.name),
                          trailing: Text(
                            code.label,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
