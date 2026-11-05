/// A member of the workspace, as `GET /organisations/{id}/users` lists them.
class OrgMember {
  final String id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String avatarUrl;
  final String defaultAvatarUrl;
  final bool online;
  final bool deactivated;

  const OrgMember({
    required this.id,
    this.name = '',
    this.username = '',
    this.email = '',
    this.phone = '',
    this.avatarUrl = '',
    this.defaultAvatarUrl = '',
    this.online = false,
    this.deactivated = false,
  });

  /// Name, then username, then email.
  String get displayName {
    for (final value in [name, username, email]) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return 'Unknown';
  }

  String get initial => displayName.substring(0, 1).toUpperCase();

  /// The uploaded avatar, else the generated default, else empty.
  String get photoUrl => avatarUrl.isNotEmpty ? avatarUrl : defaultAvatarUrl;

  factory OrgMember.fromJson(Map<String, dynamic> json) {
    String text(List<String> keys) {
      for (final key in keys) {
        final value = json[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    bool flag(String key) => json[key] == true || json[key] == 'true';

    return OrgMember(
      id: text(['id', 'user_id']),
      name: text(['name', 'full_name']),
      username: text(['username']),
      email: text(['email']),
      phone: text(['phone_number', 'phone']),
      avatarUrl: text(['avatar_url']),
      defaultAvatarUrl: text(['default_avatar_url']),
      online: flag('online'),
      deactivated: flag('is_deactivated'),
    );
  }
}

/// One page of members and the list's size.
class MembersPage {
  final List<OrgMember> members;
  final int currentPage;
  final int totalPages;

  /// All members matching the query, across pages.
  final int totalItems;

  const MembersPage({
    required this.members,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
  });

  bool get hasMore => currentPage < totalPages;
}
