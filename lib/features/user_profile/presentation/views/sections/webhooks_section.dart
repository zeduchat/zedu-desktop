import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Organisation settings page for channel webhooks: pick a channel, then
/// create its webhook, copy the URL, turn it on or off, or delete it.
class WebhooksSection extends ConsumerStatefulWidget {
  const WebhooksSection({super.key});

  @override
  ConsumerState<WebhooksSection> createState() => _WebhooksSectionState();
}

class _WebhooksSectionState extends ConsumerState<WebhooksSection> {
  final _nameController = TextEditingController();
  String? _channelId;
  WebhookModel? _webhook;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  ChannelWebhookService get _service => ref.read(channelWebhookServiceProvider);

  Future<void> _selectChannel(String? channelId) async {
    setState(() {
      _channelId = channelId;
      _webhook = null;
      _error = null;
    });
    if (channelId != null) await _load();
  }

  Future<void> _load() async {
    final channelId = _channelId;
    if (channelId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final webhook = await _service.fetch(channelId);
      if (!mounted || channelId != _channelId) return;
      setState(() {
        _webhook = webhook;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || channelId != _channelId) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this channel’s webhook.';
      });
    }
  }

  Future<void> _run(
    Future<void> Function(String channelId) action,
    String failure,
  ) async {
    final channelId = _channelId;
    if (channelId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action(channelId);
    } catch (_) {
      if (mounted) {
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: failure,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: 'Give the webhook a name.',
      );
      return;
    }
    await _run((channelId) async {
      final webhook = await _service.create(channelId, name: name);
      if (!mounted) return;
      _nameController.clear();
      setState(() => _webhook = webhook);
    }, 'Could not create the webhook. Please try again.');
  }

  Future<void> _setActive(bool active) async {
    final webhook = _webhook;
    if (webhook == null) return;
    await _run((channelId) async {
      final updated = await _service.setActive(
        channelId,
        webhook.id,
        active: active,
      );
      if (!mounted) return;
      setState(
        () => _webhook =
            updated ??
            WebhookModel(
              id: webhook.id,
              channelId: webhook.channelId,
              name: webhook.name,
              slug: webhook.slug,
              url: webhook.url,
              isActive: active,
              createdAt: webhook.createdAt,
            ),
      );
    }, 'Could not change the webhook. Please try again.');
  }

  Future<void> _delete() async {
    final webhook = _webhook;
    if (webhook == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${webhook.name}?'),
        content: const Text(
          'Anything posting to this webhook URL will stop working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('webhook-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run((channelId) async {
      await _service.delete(channelId, webhook.id);
      if (mounted) setState(() => _webhook = null);
    }, 'Could not delete the webhook. Please try again.');
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    AppToastService.show(
      context,
      type: AppToastType.success,
      message: 'Webhook URL copied',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final channels = ref.watch(channelProvider).value ?? const <Channel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Webhooks',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Let other apps post messages into a channel. Each channel can have '
          'one webhook.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          key: const ValueKey('webhook-channel-picker'),
          initialValue: _channelId,
          decoration: const InputDecoration(labelText: 'Channel'),
          items: [
            for (final channel in channels)
              DropdownMenuItem(
                value: channel.id,
                child: Text('# ${channel.name}'),
              ),
          ],
          onChanged: _busy ? null : _selectChannel,
        ),
        const SizedBox(height: 24),
        if (_channelId == null)
          Text(
            channels.isEmpty
                ? 'You have no channels yet.'
                : 'Pick a channel to see its webhook.',
            style: TextStyle(color: colors.textSecondary),
          )
        else if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Row(
            children: [
              Text(_error!, style: TextStyle(color: colors.error)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else if (_webhook == null)
          _buildCreate(colors)
        else
          _buildWebhook(colors, _webhook!),
      ],
    );
  }

  Widget _buildCreate(AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This channel has no webhook yet.',
          style: TextStyle(color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('webhook-name-field'),
                controller: _nameController,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Webhook name'),
                onSubmitted: (_) => _create(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const ValueKey('webhook-create'),
              onPressed: _busy ? null : _create,
              child: const Text('Create webhook'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebhook(AppPalette colors, WebhookModel webhook) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  webhook.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                webhook.isActive ? 'On' : 'Off',
                style: TextStyle(color: colors.textSecondary),
              ),
              Switch(
                key: const ValueKey('webhook-active'),
                value: webhook.isActive,
                onChanged: _busy ? null : _setActive,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  webhook.url,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              IconButton(
                key: const ValueKey('webhook-copy'),
                tooltip: 'Copy URL',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: webhook.url.isEmpty
                    ? null
                    : () => _copyUrl(webhook.url),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('webhook-delete'),
            onPressed: _busy ? null : _delete,
            icon: Icon(Icons.delete_outline, color: colors.error),
            label: Text(
              'Delete webhook',
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }
}
