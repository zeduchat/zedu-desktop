import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Settings → Notifications.
///
/// Keeps two copies of the preferences: the saved baseline that came from the
/// backend, and the draft shown on screen. The unsaved-changes bar shows only
/// while they differ, Revert copies the baseline back without a request, and
/// the baseline moves only when a save succeeds and new preferences arrive.
class NotificationsSection extends StatefulWidget {
  const NotificationsSection({
    super.key,
    required this.preferences,
    required this.isSaving,
    required this.onSave,
    this.workspaceName,
    this.padding = EdgeInsets.zero,
    this.maxContentWidth = double.infinity,
  });

  final NotificationPreferences preferences;
  final bool isSaving;
  final Future<void> Function(NotificationPreferences) onSave;
  final String? workspaceName;
  final EdgeInsets padding;
  final double maxContentWidth;

  @override
  State<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<NotificationsSection> {
  late NotificationPreferences _saved;
  late NotificationPreferences _draft;

  bool get _hasChanges => _draft != _saved;
  bool get _canSave =>
      _hasChanges && !widget.isSaving && _draft.hasValidQuietHours;

  @override
  void initState() {
    super.initState();
    _saved = widget.preferences;
    _draft = widget.preferences;
  }

  @override
  void didUpdateWidget(covariant NotificationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Value equality: a rebuild with the same saved values keeps the edits.
    if (oldWidget.preferences != widget.preferences) {
      _saved = widget.preferences;
      _draft = widget.preferences;
    }
  }

  void _update(NotificationPreferences preferences) {
    setState(() => _draft = preferences);
  }

  void _revert() {
    setState(() => _draft = _saved);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    await widget.onSave(_draft);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: widget.padding,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxContentWidth),
                child: _buildContent(context),
              ),
            ),
          ),
        ),
        if (_hasChanges)
          _UnsavedChangesBar(
            padding: widget.padding,
            maxContentWidth: widget.maxContentWidth,
            isSaving: widget.isSaving,
            canSave: _canSave,
            onRevert: widget.isSaving ? null : _revert,
            onSave: _save,
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final workspace = widget.workspaceName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(
          title: 'Notifications',
          subtitle: 'Choose what reaches you on this desktop, and when.',
        ),
        const SizedBox(height: 28),
        const _GroupLabel('What'),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title('Notify me about'),
              const SizedBox(height: 2),
              _Description(
                workspace == null || workspace.isEmpty
                    ? 'Applies to every channel and DM in this workspace.'
                    : 'Applies to every channel and DM in $workspace.',
              ),
              const SizedBox(height: 16),
              _ModeCards(
                value: _draft.mode,
                onChanged: (mode) => _update(_draft.copyWith(mode: mode)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const _GroupLabel('When'),
        _QuietHoursPanel(preferences: _draft, onChanged: _update),
        const SizedBox(height: 28),
        const _GroupLabel('Where'),
        _Panel(
          child: Column(
            children: [
              _ToggleRow(
                icon: Icons.mail_outline,
                title: 'Email notifications',
                description: 'Send what I miss to my account email.',
                value: _draft.emailNotifications,
                onChanged: (value) =>
                    _update(_draft.copyWith(emailNotifications: value)),
              ),
              Divider(height: 32, color: context.colors.divider),
              _ToggleRow(
                icon: Icons.smartphone_outlined,
                title: 'Use different settings on mobile',
                description:
                    'Off: your phone uses the same settings as this desktop. '
                    'On: set mobile separately in the Zedu app.',
                value: _draft.differentMobileSettings,
                onChanged: (value) =>
                    _update(_draft.copyWith(differentMobileSettings: value)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeOption {
  const _ModeOption(this.mode, this.icon, this.title, this.description);

  final NotificationMode mode;
  final IconData icon;
  final String title;
  final String description;
}

const _modeOptions = [
  _ModeOption(
    NotificationMode.allMessages,
    Icons.chat_bubble_outline,
    'All new messages',
    'Every message in your channels and DMs.',
  ),
  _ModeOption(
    NotificationMode.mentionsOnly,
    Icons.alternate_email,
    'Mentions',
    'Only when someone @mentions you or messages you directly.',
  ),
  _ModeOption(
    NotificationMode.none,
    Icons.notifications_off_outlined,
    'Nothing',
    'No desktop alerts at all. Check in when you choose.',
  ),
];

class _ModeCards extends StatelessWidget {
  const _ModeCards({required this.value, required this.onChanged});

  final NotificationMode value;
  final ValueChanged<NotificationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final option in _modeOptions)
        _ModeCard(
          option: option,
          selected: option.mode == value,
          onTap: () => onChanged(option.mode),
        ),
    ];
    return FocusTraversalGroup(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final card in cards) ...[
                  card,
                  if (card != cards.last) const SizedBox(height: 12),
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final card in cards) ...[
                  Expanded(child: card),
                  if (card != cards.last) const SizedBox(width: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ModeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(10);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '${option.title}. ${option.description}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? colors.primaryBg : colors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: selected ? colors.primary : colors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey('notification-mode-${option.mode.name}'),
          onTap: onTap,
          borderRadius: borderRadius,
          focusColor: colors.primary.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RadioDot(selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            option.icon,
                            size: 18,
                            color: selected
                                ? colors.primary
                                : colors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: _Title(option.title)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _Description(option.description),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.primary : colors.textHint,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary,
                ),
              ),
            )
          : null,
    );
  }
}

class _QuietHoursPanel extends StatelessWidget {
  const _QuietHoursPanel({required this.preferences, required this.onChanged});

  final NotificationPreferences preferences;
  final ValueChanged<NotificationPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = preferences.quietHoursEnabled;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToggleRow(
            icon: Icons.bedtime_outlined,
            title: 'Quiet hours',
            description:
                'Pause desktop notifications during set hours every day.',
            value: enabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(quietHoursEnabled: value)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    _TimeSelect(
                      key: const ValueKey('quiet-hours-pause-from'),
                      label: 'Pause from',
                      value: preferences.pauseFrom,
                      enabled: enabled,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(pauseFrom: value)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: colors.textHint,
                      ),
                    ),
                    _TimeSelect(
                      key: const ValueKey('quiet-hours-resume-at'),
                      label: 'Resume at',
                      value: preferences.resumeAt,
                      enabled: enabled,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(resumeAt: value)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _QuietHoursSummary(preferences: preferences),
                const SizedBox(height: 8),
                _Description(_timezoneNote(preferences.timezone)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _timezoneNote(String? timezone) {
    return timezone == null
        ? 'Times are in UTC because your profile has no timezone set.'
        : 'Times are in your profile timezone, $timezone.';
  }
}

/// Plain-language description of the quiet period, e.g.
/// "Notifications paused from 10:00 PM to 7:00 AM the next day".
String quietHoursSummary(NotificationPreferences preferences) {
  if (!preferences.quietHoursEnabled) {
    return 'Quiet hours are off. Notifications can arrive at any time.';
  }
  if (!preferences.hasValidQuietHours) {
    return 'Choose different pause and resume times.';
  }
  final from = formatMinutesOfDay(preferences.pauseFrom);
  final to = formatMinutesOfDay(preferences.resumeAt);
  final nextDay = preferences.quietHoursCrossMidnight ? ' the next day' : '';
  return 'Notifications paused from $from to $to$nextDay.';
}

class _QuietHoursSummary extends StatelessWidget {
  const _QuietHoursSummary({required this.preferences});

  final NotificationPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final invalid = !preferences.hasValidQuietHours;
    final active = preferences.quietHoursEnabled && !invalid;
    final foreground = invalid
        ? colors.error
        : active
        ? colors.primary
        : colors.textPrimary;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: invalid
              ? colors.errorBg
              : active
              ? colors.primaryBg
              : colors.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              invalid ? Icons.error_outline : Icons.bedtime_outlined,
              size: 16,
              color: foreground,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                quietHoursSummary(preferences),
                style: context.textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSelect extends StatelessWidget {
  const _TimeSelect({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  static const _step = 30;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Half-hour steps, plus the saved time when it falls between them.
    final options = {
      for (var m = 0; m < NotificationPreferences.minutesPerDay; m += _step) m,
      value,
    }.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileFieldLabel(label),
        const SizedBox(height: 6),
        Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.onPrimary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              focusColor: colors.primaryBg,
              dropdownColor: colors.onPrimary,
              menuMaxHeight: 320,
              icon: Icon(Icons.schedule, size: 16, color: colors.textHint),
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
              ),
              items: [
                for (final minutes in options)
                  DropdownMenuItem<int>(
                    value: minutes,
                    child: Text(formatMinutesOfDay(minutes)),
                  ),
              ],
              onChanged: enabled
                  ? (minutes) {
                      if (minutes != null) onChanged(minutes);
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primaryBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!value),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Title(title),
                  const SizedBox(height: 2),
                  _Description(description),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            activeThumbColor: colors.onPrimary,
            activeTrackColor: colors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _UnsavedChangesBar extends StatelessWidget {
  const _UnsavedChangesBar({
    required this.padding,
    required this.maxContentWidth,
    required this.isSaving,
    required this.canSave,
    required this.onRevert,
    required this.onSave,
  });

  final EdgeInsets padding;
  final double maxContentWidth;
  final bool isSaving;
  final bool canSave;
  final VoidCallback? onRevert;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const ValueKey('notifications-unsaved-bar'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.onPrimary,
        border: Border(top: BorderSide(color: colors.divider)),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(padding.left, 14, padding.right, 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'You have unsaved changes',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              AppButton.outlined(
                label: 'Revert',
                expand: false,
                height: 44,
                disabled: onRevert == null,
                onPressed: onRevert,
              ),
              const SizedBox(width: 12),
              AppButton(
                label: 'Save changes',
                expand: false,
                height: 44,
                loading: isSaving,
                disabled: !canSave,
                onPressed: onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: child,
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colors.textPrimary.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.colors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.colors.textPrimary.withValues(alpha: 0.65),
      ),
    );
  }
}
