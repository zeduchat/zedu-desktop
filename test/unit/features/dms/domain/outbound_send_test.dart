import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/dms/domain/outbound_send.dart';

void main() {
  final attemptedAt = DateTime.utc(2026, 11, 6, 9, 0, 0);

  OutboundSend send({
    String content = 'lunch at 1?',
    int attempts = 1,
    DateTime? at,
  }) {
    return OutboundSend(
      clientId: 'send-1',
      content: content,
      attempts: attempts,
      firstAttemptAt: at ?? attemptedAt,
    );
  }

  Map<String, dynamic> serverMessage({
    String id = 'server-1',
    String content = 'lunch at 1?',
    String userId = 'user-1',
    DateTime? createdAt,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) {
    return <String, dynamic>{
      'id': id,
      'content': content,
      'user_id': userId,
      'created_at': (createdAt ?? attemptedAt.add(const Duration(seconds: 4)))
          .toIso8601String(),
      ...extra,
    };
  }

  group('SendRetryPolicy', () {
    const policy = SendRetryPolicy();

    test('never retries a message that was not attempted', () {
      expect(policy.canRetry(0), isFalse);
    });

    test('stops after the attempt budget', () {
      expect(policy.canRetry(1), isTrue);
      expect(policy.canRetry(2), isTrue);
      expect(policy.canRetry(3), isFalse);
      expect(policy.canRetry(10), isFalse);
    });

    test('grows the wait exponentially and caps it', () {
      expect(policy.delayBefore(1), Duration.zero);
      expect(policy.delayBefore(2), const Duration(seconds: 3));
      expect(policy.delayBefore(3), const Duration(seconds: 6));
      expect(policy.delayBefore(4), const Duration(seconds: 12));
      expect(policy.delayBefore(5), const Duration(seconds: 24));
      expect(policy.delayBefore(6), policy.maxDelay);
      expect(policy.delayBefore(50), policy.maxDelay);
    });

    test('honours a custom multiplier and budget', () {
      const custom = SendRetryPolicy(
        maxAttempts: 2,
        initialDelay: Duration(seconds: 1),
        multiplier: 5,
      );
      expect(custom.canRetry(1), isTrue);
      expect(custom.canRetry(2), isFalse);
      expect(custom.delayBefore(2), const Duration(seconds: 1));
      expect(custom.delayBefore(3), const Duration(seconds: 5));
    });
  });

  group('OutboundSend', () {
    test('starting records the first attempt', () {
      final record = OutboundSend.starting(
        clientId: 'send-1',
        content: 'hi',
        at: attemptedAt,
      );
      expect(record.attempts, 1);
      expect(record.hasBeenAttempted, isTrue);
      expect(record.firstAttemptAt, attemptedAt);
      expect(record.lastAttemptAt, attemptedAt);
    });

    test('another attempt keeps the first attempt time and the content', () {
      final record = OutboundSend.starting(
        clientId: 'send-1',
        content: 'hi',
        at: attemptedAt,
      ).withAnotherAttempt(attemptedAt.add(const Duration(seconds: 3)));

      expect(record.attempts, 2);
      expect(record.firstAttemptAt, attemptedAt);
      expect(record.content, 'hi');
      expect(record.lastAttemptAt, attemptedAt.add(const Duration(seconds: 3)));
    });
  });

  group('normaliseMessageText', () {
    test('drops markup so the composer and server forms match', () {
      expect(
        normaliseMessageText('<p>lunch at 1?</p>'),
        normaliseMessageText('lunch at 1?'),
      );
      expect(
        normaliseMessageText('<p>a<br>b</p>'),
        normaliseMessageText('a b'),
      );
    });

    test('decodes the entities the server sends back', () {
      expect(normaliseMessageText('a &amp; b'), 'a & b');
      expect(normaliseMessageText('&lt;hi&gt;'), '<hi>');
      expect(normaliseMessageText('it&#39;s'), "it's");
      expect(normaliseMessageText('a&nbsp;b'), 'a b');
    });

    test('ignores case and runs of whitespace', () {
      expect(normaliseMessageText('  Lunch   AT 1?  '), 'lunch at 1?');
      expect(normaliseMessageText('LUNCH\nAT 1?'), 'lunch at 1?');
    });

    test('an empty message normalises to nothing', () {
      expect(normaliseMessageText(''), '');
      expect(normaliseMessageText('<p></p>'), '');
    });
  });

  group('isDeliveredCopyOf', () {
    test('matches the same sender, text and a nearby time', () {
      expect(
        isDeliveredCopyOf(serverMessage(), send: send(), senderId: 'user-1'),
        isTrue,
      );
    });

    test('matches although the server wrapped the text in markup', () {
      expect(
        isDeliveredCopyOf(
          serverMessage(content: '<p>lunch   at 1?</p>'),
          send: send(),
          senderId: 'user-1',
        ),
        isTrue,
      );
    });

    test('trusts an echoed client id over the text', () {
      expect(
        isDeliveredCopyOf(
          serverMessage(
            content: 'something else entirely',
            createdAt: attemptedAt.add(const Duration(hours: 3)),
            extra: const <String, dynamic>{'client_message_id': 'send-1'},
          ),
          send: send(),
          senderId: 'user-1',
        ),
        isTrue,
      );
    });

    test('never matches another sender', () {
      expect(
        isDeliveredCopyOf(
          serverMessage(userId: 'user-2'),
          send: send(),
          senderId: 'user-1',
        ),
        isFalse,
      );
    });

    test('does not match a different message', () {
      expect(
        isDeliveredCopyOf(
          serverMessage(content: 'lunch at 2?'),
          send: send(),
          senderId: 'user-1',
        ),
        isFalse,
      );
    });

    test('does not match an old message with the same words', () {
      expect(
        isDeliveredCopyOf(
          serverMessage(
            createdAt: attemptedAt.subtract(const Duration(minutes: 30)),
          ),
          send: send(),
          senderId: 'user-1',
        ),
        isFalse,
      );
    });

    test('does not match a message from far in the future', () {
      expect(
        isDeliveredCopyOf(
          serverMessage(
            createdAt: attemptedAt.add(const Duration(minutes: 10)),
          ),
          send: send(),
          senderId: 'user-1',
        ),
        isFalse,
      );
    });

    test('a message without a timestamp cannot be confirmed', () {
      final message = serverMessage()
        ..remove('created_at')
        ..remove('createdAt');
      expect(
        isDeliveredCopyOf(message, send: send(), senderId: 'user-1'),
        isFalse,
      );
    });

    test('an unknown sender id never matches', () {
      expect(
        isDeliveredCopyOf(serverMessage(), send: send(), senderId: ''),
        isFalse,
      );
    });
  });

  group('findDeliveredCopy', () {
    test('returns null when nothing matches', () {
      expect(
        findDeliveredCopy(
          <Map<String, dynamic>>[
            serverMessage(content: 'other'),
            serverMessage(content: 'another', userId: 'user-2'),
          ],
          send: send(),
          senderId: 'user-1',
        ),
        isNull,
      );
    });

    test('returns the newest match when several landed', () {
      final older = serverMessage(
        id: 'server-old',
        createdAt: attemptedAt.add(const Duration(seconds: 2)),
      );
      final newer = serverMessage(
        id: 'server-new',
        createdAt: attemptedAt.add(const Duration(seconds: 20)),
      );

      final found = findDeliveredCopy(
        <Map<String, dynamic>>[older, newer],
        send: send(),
        senderId: 'user-1',
      );

      expect(found, isNotNull);
      expect(found!['id'], 'server-new');
    });

    test('an empty page finds nothing', () {
      expect(
        findDeliveredCopy(
          const <Map<String, dynamic>>[],
          send: send(),
          senderId: 'user-1',
        ),
        isNull,
      );
    });
  });

  group('newClientSendId', () {
    test('is prefixed, unique and stable for a fixed random source', () {
      final first = newClientSendId(now: attemptedAt, random: Random(7));
      final second = newClientSendId(now: attemptedAt, random: Random(7));
      final later = newClientSendId(
        now: attemptedAt.add(const Duration(seconds: 1)),
        random: Random(7),
      );

      expect(first, startsWith('send-'));
      expect(first, second, reason: 'same time and same seed');
      expect(first, isNot(later));
      expect(first.split('-').length, greaterThanOrEqualTo(3));
    });

    test('two calls at the same moment differ', () {
      final a = newClientSendId(now: attemptedAt);
      final b = newClientSendId(now: attemptedAt);
      expect(a, isNot(b));
    });
  });
}
