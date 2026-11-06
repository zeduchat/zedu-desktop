import 'package:zedu/core/core.dart';

extension AppPaletteX on BuildContext {
  AppPalette get colors => Theme.of(this).brightness == Brightness.light
      ? AppPalette.light
      : AppPalette.light;
}

extension ThemeX on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
}

extension CountLabelX on int {
  /// The count with a singular or plural noun: "1 member", "3 members".
  String countLabel(String singular, [String? plural]) =>
      '$this ${this == 1 ? singular : plural ?? '${singular}s'}';

  /// Formats an unread badge counter: values greater than 99 become '99+'.
  String get unreadBadgeText => this > 99 ? '99+' : '$this';
}
