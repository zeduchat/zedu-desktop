import 'dart:async';
import 'dart:convert';

import 'package:screen_retriever/screen_retriever.dart' show screenRetriever;
import 'package:zedu/core/core.dart';

/// The size below which the sidebar, message list and composer stop fitting.
const kMinimumWindowSize = Size(960, 600);

const _boundsStorageKey = 'window_bounds';

/// How much of the title bar must be on a display for the window to be
/// reachable: enough to grab it with the mouse.
const _minVisibleTitleBar = Size(120, 32);

class SavedWindowBounds {
  const SavedWindowBounds({required this.rect, required this.isMaximized});

  final Rect rect;
  final bool isMaximized;

  String toJson() => jsonEncode({
    'x': rect.left,
    'y': rect.top,
    'width': rect.width,
    'height': rect.height,
    'maximized': isMaximized,
  });

  /// Returns null for anything that is not a complete saved value.
  static SavedWindowBounds? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SavedWindowBounds(
        rect: Rect.fromLTWH(
          (json['x'] as num).toDouble(),
          (json['y'] as num).toDouble(),
          (json['width'] as num).toDouble(),
          (json['height'] as num).toDouble(),
        ),
        isMaximized: json['maximized'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Whether enough of the window's title bar is on one of [displays] to reach
/// it, so a monitor that was disconnected can't strand the window.
bool isWindowReachable(Rect bounds, List<Rect> displays) {
  final titleBar = Rect.fromLTWH(
    bounds.left,
    bounds.top,
    bounds.width,
    _minVisibleTitleBar.height,
  );
  return displays.any((display) {
    final visible = titleBar.intersect(display);
    return visible.width >= _minVisibleTitleBar.width &&
        visible.height >= _minVisibleTitleBar.height;
  });
}

Future<List<Rect>> _readDisplayAreas() async {
  final displays = await screenRetriever.getAllDisplays();
  return [
    for (final display in displays)
      (display.visiblePosition ?? Offset.zero) &
          (display.visibleSize ?? display.size),
  ];
}

/// Enforces the minimum window size and remembers where the window was left.
class WindowBoundsController with WindowListener {
  WindowBoundsController({
    required WindowManager window,
    required SecureStorageService storage,
    Future<List<Rect>> Function() displayAreas = _readDisplayAreas,
    Duration saveDelay = const Duration(milliseconds: 500),
  }) : _window = window,
       _storage = storage,
       _displayAreas = displayAreas,
       _saveDelay = saveDelay;

  final WindowManager _window;
  final SecureStorageService _storage;
  final Future<List<Rect>> Function() _displayAreas;
  final Duration _saveDelay;

  Timer? _saveTimer;

  /// The last size and position outside the maximized state, so unmaximizing
  /// after a restart returns to it.
  Rect? _normalBounds;

  /// Runs before the first frame. A failure here must never stop the app
  /// from starting, so it falls back to the default window.
  Future<void> restore() async {
    try {
      await _window.setMinimumSize(kMinimumWindowSize);
      final saved = SavedWindowBounds.tryParse(
        await _storage.readData(_boundsStorageKey),
      );
      if (saved != null &&
          isWindowReachable(saved.rect, await _displayAreas())) {
        _normalBounds = saved.rect;
        await _window.setBounds(saved.rect);
        if (saved.isMaximized) await _window.maximize();
      }
    } catch (error) {
      debugPrint('Failed to restore window bounds: $error');
    }
    _window.addListener(this);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _save);
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    try {
      // A minimized window reports a position far off-screen on Windows.
      if (await _window.isMinimized()) return;
      final isMaximized = await _window.isMaximized();
      final bounds = await _window.getBounds();
      if (!isMaximized) _normalBounds = bounds;
      await _storage.writeData(
        _boundsStorageKey,
        SavedWindowBounds(
          rect: _normalBounds ?? bounds,
          isMaximized: isMaximized,
        ).toJson(),
      );
    } catch (error) {
      debugPrint('Failed to save window bounds: $error');
    }
  }

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowMove() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  @override
  void onWindowClose() => unawaited(_save());
}
