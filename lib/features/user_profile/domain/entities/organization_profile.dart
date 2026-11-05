import 'package:zedu/core/core.dart';

class OrganizationProfile {
  const OrganizationProfile({
    required this.id,
    required this.name,
    required this.natureOfBusiness,
    required this.country,
  });

  final String id;
  final String name;
  final String natureOfBusiness;
  final String country;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'ZO';
    // Whole characters (characters.first), so names that start with an emoji
    // or another non-BMP character aren't cut in half.
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return '${words.first.characters.first}${words.last.characters.first}'
        .toUpperCase();
  }

  OrganizationProfile copyWith({
    String? id,
    String? name,
    String? natureOfBusiness,
    String? country,
  }) {
    return OrganizationProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      natureOfBusiness: natureOfBusiness ?? this.natureOfBusiness,
      country: country ?? this.country,
    );
  }
}
