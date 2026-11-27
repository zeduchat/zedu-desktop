import 'package:zedu/core/core.dart';

/// Hosts whose https links the app trusts as its own web app (magic links, payment callbacks).
Set<String> trustedWebHosts(AppConfig config) {
  final host = Uri.tryParse(config.webBaseUrl)?.host.toLowerCase() ?? '';
  return {if (host.isNotEmpty) host};
}
