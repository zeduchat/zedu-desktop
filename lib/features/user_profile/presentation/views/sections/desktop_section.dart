import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import 'package:hotkey_manager/hotkey_manager.dart' show HotKeyModifier;

/// Settings → Desktop: how the app behaves on this computer.
class DesktopSection extends StatelessWidget {
  const DesktopSection({super.key, required this.controller});

  final WindowHotkeyController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(
          title: 'Desktop app',
          subtitle: 'Control how Zedu behaves on this computer',
        ),
        const SizedBox(height: 28),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ProfileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show or hide Zedu',
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Works from any app while Zedu is running.',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ShortcutChip(label: controller.binding.label),
                    const SizedBox(width: 12),
                    AppButton.outlined(
                      label: 'Change',
                      expand: false,
                      height: 40,
                      onPressed: () => _changeShortcut(context),
                    ),
                    const SizedBox(width: 8),
                    AppButton.ghost(
                      label: 'Reset',
                      expand: false,
                      onPressed: controller.binding == controller.defaultBinding
                          ? null
                          : () => controller.resetToDefault(),
                    ),
                  ],
                ),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.error!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _changeShortcut(BuildContext context) async {
    final binding = await showDialog<HotkeyBinding>(
      context: context,
      builder: (context) =>
          _ShortcutRecorderDialog(current: controller.binding),
    );
    if (binding == null) return;
    final applied = await controller.update(binding);
    if (!applied && context.mounted && controller.error != null) {
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: controller.error!,
      );
    }
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: context.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

class _ShortcutRecorderDialog extends StatefulWidget {
  const _ShortcutRecorderDialog({required this.current});

  final HotkeyBinding current;

  @override
  State<_ShortcutRecorderDialog> createState() =>
      _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<_ShortcutRecorderDialog> {
  HotkeyBinding? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return false;
    }
    final pressed = HardwareKeyboard.instance.physicalKeysPressed;
    final modifiers = {
      for (final modifier in HotKeyModifier.values)
        if (modifier.physicalKeys.any(pressed.contains)) modifier,
    };
    // Wait for the non-modifier key that completes the chord.
    if (modifiers.any(
      (modifier) => modifier.physicalKeys.contains(event.physicalKey),
    )) {
      setState(() => _preview = null);
      return false;
    }
    final binding = HotkeyBinding(modifiers: modifiers, key: event.logicalKey);
    if (!binding.isValid) {
      setState(() {
        _preview = binding;
        _error = 'Hold Cmd, Ctrl or Alt with another key.';
      });
      return false;
    }
    Navigator.of(context).pop(binding);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview ?? widget.current;
    return AlertDialog(
      title: const Text('Record a shortcut'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Press the combination that should show or hide Zedu.'),
          const SizedBox(height: 16),
          _ShortcutChip(label: preview.label),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actionsAlignment: MainAxisAlignment.end,
    );
  }
}
