import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Common timezones for the dropdown: the IANA id the account stores, mapped
/// to the label shown to the user.
const Map<String, String> _kTimezones = {
  'Etc/GMT+12': '(UTC-12:00) International Date Line West',
  'Pacific/Pago_Pago': '(UTC-11:00) Midway Island, Samoa',
  'Pacific/Honolulu': '(UTC-10:00) Hawaii',
  'America/Anchorage': '(UTC-09:00) Alaska',
  'America/Los_Angeles': '(UTC-08:00) Pacific Time (US & Canada)',
  'America/Denver': '(UTC-07:00) Mountain Time (US & Canada)',
  'America/Chicago': '(UTC-06:00) Central Time (US & Canada)',
  'America/New_York': '(UTC-05:00) Eastern Time (US & Canada)',
  'America/Halifax': '(UTC-04:00) Atlantic Time (Canada)',
  'America/Argentina/Buenos_Aires': '(UTC-03:00) Buenos Aires, Georgetown',
  'Atlantic/South_Georgia': '(UTC-02:00) Mid-Atlantic',
  'Atlantic/Azores': '(UTC-01:00) Azores, Cape Verde Islands',
  'Europe/London': '(UTC+00:00) London, Dublin, Lisbon',
  'Africa/Lagos': '(UTC+01:00) West Central Africa',
  'Africa/Cairo': '(UTC+02:00) Cairo, Helsinki, Bucharest',
  'Europe/Moscow': '(UTC+03:00) Moscow, Nairobi, Baghdad',
  'Asia/Dubai': '(UTC+04:00) Abu Dhabi, Muscat',
  'Asia/Karachi': '(UTC+05:00) Islamabad, Karachi',
  'Asia/Kolkata': '(UTC+05:30) Chennai, Kolkata, Mumbai',
  'Asia/Dhaka': '(UTC+06:00) Almaty, Dhaka',
  'Asia/Bangkok': '(UTC+07:00) Bangkok, Hanoi, Jakarta',
  'Asia/Singapore': '(UTC+08:00) Beijing, Singapore, Perth',
  'Asia/Tokyo': '(UTC+09:00) Tokyo, Seoul, Osaka',
  'Australia/Sydney': '(UTC+10:00) Sydney, Guam, Vladivostok',
  'Pacific/Guadalcanal': '(UTC+11:00) Solomon Islands, New Caledonia',
  'Pacific/Auckland': '(UTC+12:00) Auckland, Wellington, Fiji',
};

/// Used when the account has no timezone (matches the profile default).
const String _kDefaultTimezone = 'Africa/Lagos';

/// The IANA id to select for a saved timezone: the id itself, the id of a
/// label saved by older builds, or [_kDefaultTimezone] when empty. Unknown
/// ids are kept so saving the profile does not overwrite them.
String normalizeProfileTimezone(String saved) {
  final value = saved.trim();
  if (value.isEmpty) return _kDefaultTimezone;
  if (_kTimezones.containsKey(value)) return value;
  for (final entry in _kTimezones.entries) {
    if (entry.value == value) return entry.key;
  }
  return value;
}

String _canonicalCountryName(String value) {
  final trimmedValue = value.trim();
  return kCountries.firstWhere(
    (country) => country.toLowerCase() == trimmedValue.toLowerCase(),
    orElse: () => trimmedValue,
  );
}

/// Saves the edited profile and returns an error message, or null when the
/// save succeeded.
typedef EditProfileSave = Future<String?> Function(ProfileAccount account);

/// Opens the editor. It stays open while [onSave] runs and closes only when
/// the save succeeds; on failure it keeps the draft and shows the error.
Future<void> showEditProfileDialog(
  BuildContext context,
  ProfileAccount account,
  EditProfileSave onSave,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _EditProfileDialog(account: account, onSave: onSave),
  );
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.account, required this.onSave});

  final ProfileAccount account;
  final EditProfileSave onSave;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController displayNameCtrl;
  late final TextEditingController usernameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController titleCtrl;
  late final TextEditingController pronunciationCtrl;

  final formKey = GlobalKey<FormState>();

  late String selectedTimezone;
  late String selectedCountry;

  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.account.name);
    displayNameCtrl = TextEditingController(text: widget.account.displayName);
    usernameCtrl = TextEditingController(text: widget.account.username);
    emailCtrl = TextEditingController(text: widget.account.email);
    phoneCtrl = TextEditingController(text: widget.account.phoneNumber);
    titleCtrl = TextEditingController(text: widget.account.title);
    pronunciationCtrl = TextEditingController(
      text: widget.account.namePronunciation,
    );

    selectedTimezone = normalizeProfileTimezone(widget.account.timezone);
    selectedCountry = widget.account.country;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    displayNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    titleCtrl.dispose();
    pronunciationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final error = await widget.onSave(
      widget.account.copyWith(
        name: nameCtrl.text.trim(),
        displayName: displayNameCtrl.text.trim(),
        username: usernameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        phoneNumber: phoneCtrl.text.trim(),
        title: titleCtrl.text.trim(),
        namePronunciation: pronunciationCtrl.text.trim(),
        timezone: selectedTimezone,
        country: _canonicalCountryName(selectedCountry),
      ),
    );
    // Closed with Cancel while saving: nothing left to update or pop.
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _saveError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 640,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit your profile',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: colors.textHint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 0, color: colors.divider),

            // Scrollable form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Form(
                  key: formKey,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column — form fields
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppTextField(
                              label: 'Full Name',
                              controller: nameCtrl,
                              hint: 'Enter your full name',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Name is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Display Name',
                              controller: displayNameCtrl,
                              hint: 'Enter display name',
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'This could be your first name, or a nickname — however you\'d like people to refer to you.',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: colors.textHint,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Username',
                              controller: usernameCtrl,
                              hint: 'Enter username',
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Email',
                              controller: emailCtrl,
                              hint: 'Enter your email',
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                return Validators.validateEmail(
                                  context,
                                  v.trim(),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Phone Number',
                              controller: phoneCtrl,
                              hint: '+1 234 567 8900',
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Title',
                              controller: titleCtrl,
                              hint: 'e.g. Product Manager',
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Name Pronunciation',
                              controller: pronunciationCtrl,
                              hint: "e.g. Zoe (pronounced 'zo-ee')",
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'This could be a phonetic pronunciation, or an example of something your name sounds like.',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: colors.textHint,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Timezone dropdown
                            ProfileFieldLabel('Timezone'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: selectedTimezone,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: colors.divider),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: colors.divider),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              items: [
                                if (!_kTimezones.containsKey(selectedTimezone))
                                  DropdownMenuItem(
                                    value: selectedTimezone,
                                    child: Text(
                                      selectedTimezone,
                                      style: context.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ..._kTimezones.entries.map(
                                  (tz) => DropdownMenuItem(
                                    value: tz.key,
                                    child: Text(
                                      tz.value,
                                      style: context.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(
                                () => selectedTimezone = v ?? selectedTimezone,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Country dropdown (searchable)
                            ProfileFieldLabel('Country'),
                            const SizedBox(height: 6),
                            Autocomplete<String>(
                              initialValue: TextEditingValue(
                                text: selectedCountry,
                              ),
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return kCountries;
                                }
                                return kCountries.where(
                                  (c) => c.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  ),
                                );
                              },
                              onSelected: (value) {
                                setState(() => selectedCountry = value);
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      onChanged: (value) => selectedCountry =
                                          _canonicalCountryName(value),
                                      validator: (value) {
                                        final country = _canonicalCountryName(
                                          value ?? '',
                                        );
                                        if (country.isEmpty ||
                                            kCountries.contains(country)) {
                                          return null;
                                        }
                                        return 'Select a country from the list';
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Search or select a country',
                                        hintStyle: context.textTheme.bodySmall
                                            ?.copyWith(color: colors.textHint),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.divider,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.divider,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 14,
                                            ),
                                        suffixIcon: Icon(
                                          Icons.keyboard_arrow_down,
                                          color: colors.textHint,
                                        ),
                                      ),
                                      style: context.textTheme.bodySmall,
                                      onFieldSubmitted: (_) =>
                                          onFieldSubmitted(),
                                    );
                                  },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 360,
                                          constraints: const BoxConstraints(
                                            maxHeight: 240,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.background,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: colors.divider,
                                            ),
                                          ),
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (context, index) {
                                              final option = options.elementAt(
                                                index,
                                              );
                                              return InkWell(
                                                onTap: () => onSelected(option),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                  child: Text(
                                                    option,
                                                    style: context
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Right column — profile photo
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Photo',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: colors.textHint,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 80,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  // Upload photo placeholder
                                },
                                icon: Icon(
                                  Icons.upload_outlined,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                label: Text(
                                  'Upload photo',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  // Remove photo placeholder
                                },
                                child: Text(
                                  'Remove photo',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: colors.error,
                                    fontWeight: FontWeight.w500,
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
              ),
            ),

            // Footer
            Divider(height: 0, color: colors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_saveError != null)
                    Expanded(
                      child: Text(
                        _saveError!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Save changes',
                    expand: false,
                    height: 40,
                    loading: _saving,
                    onPressed: _saving ? null : _save,
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
