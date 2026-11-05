import 'package:zedu/core/core.dart';

/// The app's version and build number from the build itself, such as
/// `0.1.0 (1)`.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
});
