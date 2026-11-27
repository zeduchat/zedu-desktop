import 'dart:async';
import 'dart:convert';

import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:zedu/core/core.dart';

const kShowHideHotkeyStorageKey = 'desktop_show_hide_hotkey';

const _hotkeyIdentifier = 'zedu-show-hide-window';

/// A shortcut the user picked: at least one non-shift modifier plus a key.
class HotkeyBinding {
  const HotkeyBinding({required this.modifiers, required this.key});

  final Set<HotKeyModifier> modifiers;
  final LogicalKeyboardKey key;

  static HotkeyBinding defaultFor(TargetPlatform platform) {
    return HotkeyBinding(
      modifiers: {
        platform == TargetPlatform.macOS
            ? HotKeyModifier.meta
            : HotKeyModifier.control,
        HotKeyModifier.shift,
      },
      key: LogicalKeyboardKey.keyZ,
    );
  }

  /// The leading modifier must be Cmd, Ctrl or Alt: Shift alone would take a
  /// key away from normal typing everywhere on the system.
  bool get isValid =>
      modifiers.any(
        (modifier) =>
            modifier == HotKeyModifier.meta ||
            modifier == HotKeyModifier.control ||
            modifier == HotKeyModifier.alt,
      ) &&
      !_isModifierKey(key) &&
      key != LogicalKeyboardKey.escape;

  String get label => [
    if (modifiers.contains(HotKeyModifier.control)) 'Ctrl',
    if (modifiers.contains(HotKeyModifier.alt)) 'Alt',
    if (modifiers.contains(HotKeyModifier.shift)) 'Shift',
    if (modifiers.contains(HotKeyModifier.meta))
      defaultTargetPlatform == TargetPlatform.macOS ? 'Cmd' : 'Win',
    key.keyLabel,
  ].join(' + ');

  String toJson() => jsonEncode({
    'modifiers': [for (final modifier in modifiers) modifier.name],
    'keyId': key.keyId,
  });

  /// Returns null for anything that is not a complete, valid binding.
  static HotkeyBinding? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final key = LogicalKeyboardKey.findKeyByKeyId(json['keyId'] as int);
      if (key == null) return null;
      final modifiers = {
        for (final name in (json['modifiers'] as List<dynamic>))
          HotKeyModifier.values.firstWhere((modifier) => modifier.name == name),
      };
      final binding = HotkeyBinding(modifiers: modifiers, key: key);
      return binding.isValid ? binding : null;
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is HotkeyBinding &&
      other.key == key &&
      other.modifiers.length == modifiers.length &&
      other.modifiers.containsAll(modifiers);

  @override
  int get hashCode => Object.hash(key, Object.hashAllUnordered(modifiers));
}

final _modifierKeys = {
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.fn,
};

bool _isModifierKey(LogicalKeyboardKey key) => _modifierKeys.contains(key);

/// The part of the system shortcut API the controller needs, so lifecycle
/// logic can be tested without a platform channel.
abstract class SystemHotkeyRegistrar {
  Future<void> register(HotKey hotKey, {required void Function() onPressed});

  Future<void> unregister(HotKey hotKey);
}

class HotkeyManagerRegistrar implements SystemHotkeyRegistrar {
  @override
  Future<void> register(HotKey hotKey, {required void Function() onPressed}) {
    return hotKeyManager.register(hotKey, keyDownHandler: (_) => onPressed());
  }

  @override
  Future<void> unregister(HotKey hotKey) => hotKeyManager.unregister(hotKey);
}

/// Registers the show/hide shortcut and keeps it in sync with the user's
/// choice. Registration failures are reported through [error] and never stop
/// the app from starting.
class WindowHotkeyController extends ChangeNotifier {
  WindowHotkeyController({
    required WindowManager window,
    required SecureStorageService storage,
    SystemHotkeyRegistrar? registrar,
    HotkeyBinding? defaultBinding,
  }) : _window = window,
       _storage = storage,
       _registrar = registrar ?? HotkeyManagerRegistrar(),
       _defaultBinding =
           defaultBinding ?? HotkeyBinding.defaultFor(defaultTargetPlatform);

  final WindowManager _window;
  final SecureStorageService _storage;
  final SystemHotkeyRegistrar _registrar;
  final HotkeyBinding _defaultBinding;

  HotkeyBinding? _registered;
  HotKey? _hotKey;

  /// The previous shortcut when a failed change could not put it back, so
  /// settings keep showing what the user had instead of the default.
  HotkeyBinding? _unrestored;
  String? _error;

  HotkeyBinding get defaultBinding => _defaultBinding;

  /// The shortcut in force, or the default while the saved one is loading.
  HotkeyBinding get binding => _registered ?? _unrestored ?? _defaultBinding;

  String? get error => _error;

  bool get isRegistered => _registered != null;

  Future<void> start() async {
    HotkeyBinding binding = _defaultBinding;
    try {
      final saved = HotkeyBinding.tryParse(
        await _storage.readData(kShowHideHotkeyStorageKey),
      );
      if (saved != null) binding = saved;
    } catch (error) {
      debugPrint('Failed to read the show/hide shortcut: $error');
    }
    await _register(binding);
  }

  /// Applies [next], keeping the previous shortcut registered if it fails.
  Future<bool> update(HotkeyBinding next) async {
    if (!next.isValid) {
      _error = 'Use Cmd, Ctrl or Alt with another key.';
      notifyListeners();
      return false;
    }
    if (next == _registered) {
      _error = null;
      notifyListeners();
      return true;
    }
    final previous = _registered;
    if (!await _unregister()) {
      // The current shortcut is still held, so leave it in force.
      _error = "Couldn't release the current shortcut. Try again.";
      notifyListeners();
      return false;
    }
    if (!await _register(next)) {
      final message = _error;
      if (previous != null) {
        if (await _register(previous)) {
          _error = message;
        } else {
          _unrestored = previous;
          _error = "$message Couldn't restore the previous shortcut.";
        }
        notifyListeners();
      }
      return false;
    }
    try {
      await _storage.writeData(kShowHideHotkeyStorageKey, next.toJson());
    } catch (error) {
      debugPrint('Failed to save the show/hide shortcut: $error');
    }
    return true;
  }

  Future<bool> resetToDefault() => update(_defaultBinding);

  Future<bool> _register(HotkeyBinding binding) async {
    final hotKey = HotKey(
      identifier: _hotkeyIdentifier,
      key: binding.key,
      modifiers: binding.modifiers.toList(),
      scope: HotKeyScope.system,
    );
    try {
      await _registrar.register(hotKey, onPressed: toggleWindow);
    } catch (error) {
      debugPrint('Failed to register the show/hide shortcut: $error');
      _error = 'That shortcut is already used by another app.';
      notifyListeners();
      return false;
    }
    _hotKey = hotKey;
    _registered = binding;
    _unrestored = null;
    _error = null;
    notifyListeners();
    return true;
  }

  /// Releases the current shortcut. Its state is only cleared once the system
  /// confirms, so a failed release leaves it recorded as still in force.
  Future<bool> _unregister() async {
    final hotKey = _hotKey;
    if (hotKey == null) {
      _registered = null;
      return true;
    }
    try {
      await _registrar.unregister(hotKey);
    } catch (error) {
      debugPrint('Failed to unregister the show/hide shortcut: $error');
      return false;
    }
    _hotKey = null;
    _registered = null;
    return true;
  }

  /// Shows and focuses the window when it is hidden, minimized or covered,
  /// and hides it when it already has focus.
  Future<void> toggleWindow() async {
    try {
      if (await _window.isMinimized()) {
        await _window.restore();
        await _window.show();
        await _window.focus();
        return;
      }
      if (await _window.isVisible() && await _window.isFocused()) {
        await _window.hide();
        return;
      }
      await _window.show();
      await _window.focus();
    } catch (error) {
      debugPrint('Failed to toggle the window from its shortcut: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_unregister());
    super.dispose();
  }
}
