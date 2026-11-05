import 'package:zedu/core/core.dart';

class ProfileAccount {
  const ProfileAccount({
    required this.name,
    required this.email,
    required this.timezone,
    this.avatarUrl,
    this.displayName = '',
    this.username = '',
    this.phoneNumber = '',
    this.title = '',
    this.namePronunciation = '',
    this.country = '',
  });

  factory ProfileAccount.empty() => const ProfileAccount(
    name: 'Anonymous user',
    email: 'anonymoususer@email.com',
    timezone: 'Africa/Lagos',
  );

  final String name;
  final String email;
  final String timezone;
  final String? avatarUrl;
  final String displayName;
  final String username;
  final String phoneNumber;
  final String title;
  final String namePronunciation;
  final String country;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'ZU';
    // Whole characters (characters.first), so names that start with an emoji
    // or another non-BMP character aren't cut in half.
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  ProfileAccount copyWith({
    String? name,
    String? email,
    String? timezone,
    String? avatarUrl,
    String? displayName,
    String? username,
    String? phoneNumber,
    String? title,
    String? namePronunciation,
    String? country,
  }) {
    return ProfileAccount(
      name: name ?? this.name,
      email: email ?? this.email,
      timezone: timezone ?? this.timezone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      title: title ?? this.title,
      namePronunciation: namePronunciation ?? this.namePronunciation,
      country: country ?? this.country,
    );
  }
}
