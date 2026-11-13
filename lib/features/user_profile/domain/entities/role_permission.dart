class RolePermission {
  const RolePermission({
    this.id,
    required this.role,
    required this.description,
    required this.permissions,
  });

  final String? id;
  final String role;
  final String description;
  final List<String> permissions;
}
