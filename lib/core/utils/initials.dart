import 'package:zedu/core/core.dart';

/// The first character of [name] for an avatar, upper-cased, or [fallback]
/// when there is none.
///
/// It takes a whole character (a grapheme), so a name that starts with an
/// emoji, a flag or another non-BMP character isn't cut in half the way
/// `name[0]` cuts it.
String avatarInitial(String? name, {String fallback = '?'}) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;
  return trimmed.characters.first.toUpperCase();
}
