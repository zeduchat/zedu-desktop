import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Lets the user choose which messages in one channel notify them, and mute
/// it, saved through the channel's notification preference.
class ChannelNotificationDialog extends ConsumerStatefulWidget {
  const ChannelNotificationDialog({super.key, required this.channel});

  final Channel channel;

  static Future<void> show(BuildContext context, Channel channel) {
    return showDialog<void>(
      context: context,
      builder: (_) => ChannelNotificationDialog(channel: channel),
    );
  }

  @override
  ConsumerState<ChannelNotificationDialog> createState() =>
      _ChannelNotificationDialogState();
}

class _ChannelNotificationDialogState
    extends ConsumerState<ChannelNotificationDialog> {
  ChannelNotificationPreference _preference =
      const ChannelNotificationPreference();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final preference = await ref
          .read(channelNotificationServiceProvider)
          .load(widget.channel.id);
      if (!mounted) return;
      setState(() {
        _preference = preference;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load your notification settings.';
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final overlay = Overlay.of(context, rootOverlay: true);
    try {
      await ref
          .read(channelNotificationServiceProvider)
          .save(widget.channel.id, _preference);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToastService.showWith(
        overlay,
        type: AppToastType.success,
        message: 'Notification settings saved for #${widget.channel.name}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToastService.showWith(
        overlay,
        type: AppToastType.error,
        message: 'Could not save. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget option(ChannelNotificationLevel level, String label) {
      return RadioListTile<ChannelNotificationLevel>(
        key: ValueKey('channel-notification-${level.name}'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label, style: TextStyle(color: colors.textPrimary)),
        value: level,
      );
    }

    final Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_loadError != null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!, style: TextStyle(color: colors.error)),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send a notification for',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          RadioGroup<ChannelNotificationLevel>(
            key: const ValueKey('channel-notification-level'),
            groupValue: _preference.level,
            onChanged: (value) {
              if (_saving || value == null) return;
              setState(() => _preference = _preference.copyWith(level: value));
            },
            child: Column(
              children: [
                option(ChannelNotificationLevel.all, 'All new messages'),
                option(ChannelNotificationLevel.mentions, 'Mentions'),
                option(ChannelNotificationLevel.channels, 'Channels'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const ValueKey('channel-notification-mute'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Mute this channel',
              style: TextStyle(color: colors.textPrimary),
            ),
            value: _preference.muted,
            onChanged: _saving
                ? null
                : (value) => setState(
                    () => _preference = _preference.copyWith(
                      muted: value ?? false,
                    ),
                  ),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text('Notifications for #${widget.channel.name}'),
      content: SizedBox(width: 360, child: body),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('channel-notification-save'),
          onPressed: _loading || _loadError != null || _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
