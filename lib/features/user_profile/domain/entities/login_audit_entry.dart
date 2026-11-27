/// One sign-in from the user's login history
/// (`GET /users/{userId}/login-audit`).
class LoginAuditEntry {
  const LoginAuditEntry({
    required this.id,
    required this.device,
    required this.location,
    required this.ipAddress,
    required this.loginAt,
    required this.createdAt,
    required this.isLive,
  });

  final String id;
  final String device;
  final String location;
  final String ipAddress;
  final DateTime? loginAt;
  final DateTime? createdAt;

  /// Whether the session started by this sign-in is still active.
  final bool isLive;
}

/// One page of [LoginAuditEntry] items.
class LoginAuditPage {
  const LoginAuditPage({
    required this.entries,
    required this.currentPage,
    required this.totalPages,
  });

  const LoginAuditPage.empty()
    : entries = const [],
      currentPage = 1,
      totalPages = 0;

  final List<LoginAuditEntry> entries;
  final int currentPage;
  final int totalPages;

  bool get hasMore => currentPage < totalPages;
}
