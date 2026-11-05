/// Outcome of a presence toggle attempt.
///
/// Distinguishes a confirmed change from a real failure and from a no-op
/// (duplicate request, stale session, signed out) so the UI only surfaces
/// error feedback for genuine failures.
sealed class PresenceToggleResult {
  const PresenceToggleResult();
}

/// The backend confirmed the presence change and local state was updated.
class PresenceConfirmed extends PresenceToggleResult {
  const PresenceConfirmed();
}

/// The request failed while the session was still current; `message` is the
/// user-facing error to display.
class PresenceFailed extends PresenceToggleResult {
  const PresenceFailed(this.message);

  final String message;
}

/// No request was made or the response no longer applies (busy, signed out,
/// account or organisation changed mid-flight). Never user-facing.
class PresenceSkipped extends PresenceToggleResult {
  const PresenceSkipped();
}
