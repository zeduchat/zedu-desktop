import 'package:zedu/core/core.dart';

/// The web hosts whose `https` links the app treats as its own, such as
/// magic-link and payment callbacks opened from the browser or an email.
///
/// This is only the host of [AppConfig.webBaseUrl] (for example `zedu.chat`
/// in production and `staging.zedu.chat` on staging), lower-cased. Callers
/// must compare hosts for exact equality: suffix matching would let
/// lookalikes such as `evilzedu.chat` or `zedu.chat.evil.com` through.
Set<String> trustedWebHosts(AppConfig config) {
  final host = Uri.tryParse(config.webBaseUrl)?.host.toLowerCase() ?? '';
  return host.isEmpty ? const <String>{} : {host};
}
