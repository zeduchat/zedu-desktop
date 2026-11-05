import 'package:window_manager/window_manager.dart';

/// Shows and focuses the window once Flutter is ready to draw, so a launch
/// never leaves a blank window on screen.
void showWindowWhenReady(WindowManager window) {
  window.waitUntilReadyToShow(null, () async {
    await window.show();
    await window.focus();
  });
}
