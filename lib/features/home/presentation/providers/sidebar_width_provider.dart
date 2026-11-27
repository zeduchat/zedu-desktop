import 'package:zedu/core/core.dart';

/// The width the user dragged the Home sidebar to, kept for the session so
/// it survives leaving Home (for example opening Settings). Null until the
/// user resizes it, which means the sidebar's default width.
class SidebarWidthNotifier extends Notifier<double?> {
  @override
  double? build() => null;

  void setWidth(double width) => state = width;
}

final sidebarWidthProvider = NotifierProvider<SidebarWidthNotifier, double?>(
  SidebarWidthNotifier.new,
);
