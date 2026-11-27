class SecuritySession {
  const SecuritySession({
    this.id = '',
    required this.device,
    required this.location,
    required this.date,
    required this.lastActive,
    required this.status,
    this.isLive = false,
  });

  /// The session's access token id, which revoking it needs. Empty when the
  /// server didn't send one.
  final String id;
  final String device;
  final String location;
  final String date;
  final String lastActive;
  final String status;

  /// Whether the session is still signed in.
  final bool isLive;

  /// Only a live session the server identified can be signed out.
  bool get canRevoke => isLive && id.isNotEmpty;
}
