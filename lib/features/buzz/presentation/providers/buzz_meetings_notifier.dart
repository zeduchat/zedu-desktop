import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Which Buzz action is running, if any.
enum BuzzMeetingAction { none, startNow, createForLater }

/// Creates meetings and builds their links for the Buzz page.
class BuzzMeetingsNotifier extends Notifier<BuzzMeetingAction> {
  @override
  BuzzMeetingAction build() => BuzzMeetingAction.none;

  /// Shown when Join has no session to build the link from.
  static const signInToJoinMessage = 'Sign in again to join a meeting.';

  /// Shown when Join is used while signed in but the workspace slug the
  /// link needs is missing, e.g. after a restored session.
  static const workspaceMissingJoinMessage =
      "Couldn't open this meeting: your workspace isn't loaded. "
      'Sign out and back in, then try again.';

  /// Shown when a meeting is started with no session.
  static const signInToStartMessage = 'Sign in again to start a meeting.';

  /// Shown when a meeting is started while signed in but without the
  /// workspace slug.
  static const workspaceMissingStartMessage =
      "Couldn't start a meeting: your workspace isn't loaded. "
      'Sign out and back in, then try again.';

  String get _orgSlug => ref.read(buzzOrgSlugProvider);

  bool get _isSignedIn => ref.read(buzzSignedInProvider);

  /// The link to meeting [code], or null when the organisation is unknown.
  Uri? linkFor(String code, {bool directJoin = false}) {
    final slug = _orgSlug;
    if (slug.isEmpty || code.isEmpty) return null;
    return buzzMeetingUrl(
      webBaseUrl: ref.read(buzzConfigProvider).webBaseUrl,
      orgSlug: slug,
      code: code,
      directJoin: directJoin,
    );
  }

  /// The link to meeting [code], or a failure with a message for the
  /// person: sign in again only when there is no session.
  Result<Uri> joinLink(String code) {
    final link = linkFor(code);
    if (link != null) return Success(link);
    return Failure(
      ApiFailure(
        message: _isSignedIn
            ? workspaceMissingJoinMessage
            : signInToJoinMessage,
      ),
    );
  }

  /// Creates a meeting and returns its link, or a failure with a message
  /// for the person. [startNow] links straight into the meeting.
  Future<Result<Uri>> create({required bool startNow}) async {
    if (state != BuzzMeetingAction.none) {
      return const Failure(ApiFailure(message: 'Already creating a meeting.'));
    }
    if (_orgSlug.isEmpty) {
      return Failure(
        ApiFailure(
          message: _isSignedIn
              ? workspaceMissingStartMessage
              : signInToStartMessage,
        ),
      );
    }
    state = startNow
        ? BuzzMeetingAction.startNow
        : BuzzMeetingAction.createForLater;
    try {
      final result = await ref
          .read(buzzMeetingsRepositoryProvider)
          .createMeeting();
      return switch (result) {
        Success<String>(:final value) => Success(
          linkFor(value, directJoin: startNow)!,
        ),
        Failure<String>() => const Failure(
          ApiFailure(message: 'Failed to create meeting. Please try again.'),
        ),
      };
    } finally {
      if (ref.mounted) state = BuzzMeetingAction.none;
    }
  }
}
