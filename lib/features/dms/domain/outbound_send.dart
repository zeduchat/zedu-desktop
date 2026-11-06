import 'dart:math';

/// How many times a message that failed to send is retried by itself, and how
/// long the app waits before each attempt.
///
/// The waits grow exponentially from [initialDelay] up to [maxDelay], so a
/// short blip is retried almost at once while a real outage is not hammered.
/// Nothing here is random: a fixed schedule is what makes the behaviour
/// testable and predictable for the person waiting.
class SendRetryPolicy {
  const SendRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 3),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2,
  });

  /// Total attempts allowed for one message, the first one included.
  final int maxAttempts;

  /// The wait before the second attempt.
  final Duration initialDelay;

  /// The longest wait the schedule can produce.
  final Duration maxDelay;

  /// How much each wait grows.
  final int multiplier;

  /// Whether another attempt is allowed after [attemptsSoFar] attempts.
  bool canRetry(int attemptsSoFar) =>
      attemptsSoFar > 0 && attemptsSoFar < maxAttempts;

  /// The wait before attempt number [attempt] (the first attempt is 1).
  ///
  /// Attempts at or below 1 have no wait; later ones double up to [maxDelay].
  Duration delayBefore(int attempt) {
    if (attempt <= 1) return Duration.zero;
    var millis = initialDelay.inMilliseconds;
    for (var i = 2; i < attempt; i++) {
      millis *= multiplier;
      if (millis >= maxDelay.inMilliseconds) return maxDelay;
    }
    return millis >= maxDelay.inMilliseconds
        ? maxDelay
        : Duration(milliseconds: millis);
  }
}

/// What the app remembers about one message it is trying to send.
///
/// The id is created once, when the message is first shown, and every attempt
/// reuses it. That is what lets a retry recognise the message it already tried
/// to send instead of treating it as a brand-new one.
class OutboundSend {
  const OutboundSend({
    required this.clientId,
    required this.content,
    required this.attempts,
    required this.firstAttemptAt,
    this.lastAttemptAt,
  });

  /// Starts the record for a message that is about to be sent for the first
  /// time.
  factory OutboundSend.starting({
    required String clientId,
    required String content,
    required DateTime at,
  }) {
    return OutboundSend(
      clientId: clientId,
      content: content,
      attempts: 1,
      firstAttemptAt: at,
      lastAttemptAt: at,
    );
  }

  /// The message id this record belongs to.
  final String clientId;

  /// The text as the person typed it, used to recognise a delivered copy.
  final String content;

  /// Attempts made so far, the first one included.
  final int attempts;

  /// When the first attempt started. A copy of the message that reached the
  /// server because of that attempt cannot be older than this.
  final DateTime firstAttemptAt;

  /// When the most recent attempt started.
  final DateTime? lastAttemptAt;

  /// A copy of this record with one more attempt recorded at [at].
  OutboundSend withAnotherAttempt(DateTime at) => OutboundSend(
    clientId: clientId,
    content: content,
    attempts: attempts + 1,
    firstAttemptAt: firstAttemptAt,
    lastAttemptAt: at,
  );

  /// Whether the message has been attempted at all.
  bool get hasBeenAttempted => attempts > 0;
}

/// The text of [raw] reduced to what two copies of the same message share.
///
/// The composer sends HTML-ish content (`<p>hello</p>`), the server may return
/// it with different wrapping or entities, and typing differences such as
/// double spaces or trailing newlines must not hide a duplicate. Tags are
/// dropped, the common entities decoded, whitespace collapsed and the result
/// compared case-insensitively.
String normaliseMessageText(String raw) {
  var text = raw;
  // Tags carry no meaning for this comparison; a break becomes a space so
  // "a<br>b" and "a b" are the same message.
  text = text.replaceAll(RegExp('<[^>]*>'), ' ');
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.toLowerCase();
}

/// Whether [serverMessage] is a copy of [send] that already reached the server.
///
/// Used before a retry: if an earlier attempt was committed even though the
/// client saw a failure, sending again would post the message twice. A match
/// needs all three of the following:
///
/// * the sender is the person who sent it (never someone else's message with
///   the same text);
/// * the normalised text is identical;
/// * it was created within [tolerance] of the first attempt, so an old message
///   with the same words does not count.
///
/// A server that echoes the client id back in any of the usual fields is
/// trusted over the content comparison.
bool isDeliveredCopyOf(
  Map<String, dynamic> serverMessage, {
  required OutboundSend send,
  required String senderId,
  Duration tolerance = const Duration(minutes: 2),
}) {
  for (final key in const <String>[
    'client_id',
    'clientId',
    'client_message_id',
    'clientMessageId',
    'idempotency_key',
    'idempotencyKey',
  ]) {
    final echoed = serverMessage[key]?.toString();
    if (echoed != null && echoed == send.clientId) return true;
  }

  final messageSender = (serverMessage['user_id'] ?? serverMessage['userId'])
      ?.toString();
  if (senderId.isEmpty || messageSender != senderId) return false;

  final content = (serverMessage['content'] ?? serverMessage['text'] ?? '')
      .toString();
  if (normaliseMessageText(content) != normaliseMessageText(send.content)) {
    return false;
  }

  final createdAt = DateTime.tryParse(
    (serverMessage['created_at'] ?? serverMessage['createdAt'] ?? '').toString(),
  );
  if (createdAt == null) return false;

  final earliest = send.firstAttemptAt.subtract(const Duration(seconds: 5));
  return !createdAt.isBefore(earliest) &&
      createdAt.isAfter(send.firstAttemptAt.subtract(tolerance)) &&
      createdAt.isBefore(send.firstAttemptAt.add(tolerance));
}

/// The newest message in [page] that is a delivered copy of [send], if any.
Map<String, dynamic>? findDeliveredCopy(
  List<Map<String, dynamic>> page, {
  required OutboundSend send,
  required String senderId,
  Duration tolerance = const Duration(minutes: 2),
}) {
  Map<String, dynamic>? newest;
  DateTime? newestAt;
  for (final message in page) {
    if (!isDeliveredCopyOf(
      message,
      send: send,
      senderId: senderId,
      tolerance: tolerance,
    )) {
      continue;
    }
    final at = DateTime.tryParse(
      (message['created_at'] ?? message['createdAt'] ?? '').toString(),
    );
    if (newest == null || (at != null && (newestAt == null || at.isAfter(newestAt)))) {
      newest = message;
      newestAt = at;
    }
  }
  return newest;
}

/// A new id for one message, reused by every attempt to send it.
///
/// It is readable and obviously client-side (`send-`), sorts by creation time,
/// and carries randomness so two messages created in the same microsecond on
/// different devices cannot collide.
String newClientSendId({DateTime? now, Random? random}) {
  final clock = now ?? DateTime.now();
  final rng = random ?? Random.secure();
  final suffix = rng.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
  return 'send-${clock.microsecondsSinceEpoch}-$suffix';
}
