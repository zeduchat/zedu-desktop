import '../../../../helpers/helpers.dart';
import 'package:zedu/features/features.dart';

void main() {
  test('ChannelMessage.fromJson maps a thread', () {
    final message = ChannelMessage.fromJson({
      'thread_id': 't-1',
      'full_name': 'Ada Lovelace',
      'avatar_url': 'https://cdn.zedu.chat/a.png',
      'message': 'hello',
      'created_at': '2026-10-21T05:14:46Z',
    });

    expect(message.id, 't-1');
    expect(message.dedupeKey, 't-1');
    expect(message.senderName, 'Ada Lovelace');
    expect(message.avatarUrl, 'https://cdn.zedu.chat/a.png');
    expect(message.createdAt, DateTime.utc(2026, 10, 21, 5, 14, 46).toLocal());
  });

  test('ChannelMessage.fromJson falls back and strips HTML', () {
    final message = ChannelMessage.fromJson({
      'full_name': ' ',
      'username': 'gold_salam',
      'default_avatar_url': 'https://cdn.zedu.chat/default.png',
      'message':
          '<p>Hi &amp; welcome</p><div>Line&nbsp;two</div><ul><li>a</li><li>b</li></ul>',
    });

    expect(message.id, isNull);
    expect(message.senderName, 'gold_salam');
    expect(message.avatarUrl, 'https://cdn.zedu.chat/default.png');
    expect(message.text, 'Hi & welcome\nLine two\na\nb');

    expect(message.rawContent, contains('<p>Hi &amp; welcome</p>'));
    expect(message.media, isEmpty);
    // Without an id, the content identifies the message.
    expect(message.dedupeKey, contains('gold_salam'));
  });

  group('ChannelMessage.fromJson parses media attachments (#2681)', () {
    test('extracts media list with name, link and type', () {
      final message = ChannelMessage.fromJson({
        'message': 'Check this file',
        'media': [
          {
            'file_name': 'photo.png',
            'file_link': 'https://cdn.zedu.chat/photo.png',
            'file_type': 'png',
          },
        ],
      });

      expect(message.media.length, 1);
      final item = message.media.first as Map;
      expect(item['file_name'], 'photo.png');
      expect(item['file_link'], 'https://cdn.zedu.chat/photo.png');
      expect(item['file_type'], 'png');
    });

    test('falls back to files or attachments and skips non-map items', () {
      final message = ChannelMessage.fromJson({
        'message': 'Fallback test',
        'files': [
          'invalid_string',
          42,
          {
            'name': 'document.pdf',
            'url': 'https://cdn.zedu.chat/doc.pdf',
            'type': 'pdf',
          },
        ],
      });

      expect(message.media.length, 1);
      final item = message.media.first as Map;
      expect(item['name'], 'document.pdf');
    });

    test(
      'defaults to empty list when media is missing, null, or malformed',
      () {
        final msg1 = ChannelMessage.fromJson({'message': 'plain text'});
        final msg2 = ChannelMessage.fromJson({
          'message': 'plain text',
          'media': null,
        });
        final msg3 = ChannelMessage.fromJson({
          'message': 'plain text',
          'media': 'not-a-list',
        });

        expect(msg1.media, isEmpty);
        expect(msg2.media, isEmpty);
        expect(msg3.media, isEmpty);
      },
    );
  });

  group('ChannelMessage.fromJson reactions', () {
    test('maps the reaction list from the thread payload', () {
      final message = ChannelMessage.fromJson({
        'reactions': [
          {'reaction': '👍', 'reaction_id': 'r-1', 'reaction_count': 3},
          {'reaction': '🔥', 'reaction_id': 'r-2', 'reaction_count': 1},
        ],
      });

      expect(message.reactions, hasLength(2));
      expect(message.reactions[0].emoji, '👍');
      expect(message.reactions[0].reactionId, 'r-1');
      expect(message.reactions[0].count, 3);
      expect(message.reactions[1].emoji, '🔥');
      expect(message.reactions[1].reactionId, 'r-2');
      expect(message.reactions[1].count, 1);
    });

    test('tolerates missing, null, and non-map entries', () {
      final message = ChannelMessage.fromJson({
        'reactions': [
          null,
          'garbage',
          {'reaction': '🎉'},
        ],
      });

      expect(message.reactions, hasLength(1));
      expect(message.reactions.single.emoji, '🎉');
      expect(message.reactions.single.reactionId, '');
      expect(message.reactions.single.count, 0);
    });

    test('defaults to no reactions when the field is absent', () {
      expect(ChannelMessage.fromJson({}).reactions, isEmpty);
    });
  });

  group('ChannelMessage.fromJson decodes HTML entities', () {
    String textOf(String html) =>
        ChannelMessage.fromJson({'message': html}).text;

    test('shows the characters the web editor escapes', () {
      expect(textOf('<p>if a &lt; b and b &gt; c</p>'), 'if a < b and b > c');
      expect(textOf('<p>I &lt;3 this</p>'), 'I <3 this');
      expect(
        textOf('<p>&quot;quoted&quot; &apos;text&apos;</p>'),
        '"quoted" \'text\'',
      );
    });

    test('decodes numeric entities', () {
      expect(textOf('it&#39;s &#x27;ok&#X27; &#128512;'), "it's 'ok' 😀");
    });

    test('decodes once, so an escaped entity stays as typed', () {
      expect(textOf('<p>type &amp;lt; for &lt;</p>'), 'type &lt; for <');
    });

    test('leaves anything that is not a valid entity alone', () {
      expect(
        textOf('AT&T &bogus; &#xFFFFFFF; &#xD800; &lt'),
        'AT&T &bogus; &#xFFFFFFF; &#xD800; &lt',
      );
    });
    test(
      'preserves typed text with angle brackets, generics, and comparisons',
      () {
        expect(textOf('Use List<String> here'), 'Use List<String> here');
        expect(
          textOf('Call `Map<String, int> m` now'),
          'Call `Map<String, int> m` now',
        );
        expect(
          textOf('wrap it in a <div> element'),
          'wrap it in a <div> element',
        );
        expect(textOf('if a<b and c>d then'), 'if a<b and c>d then');
        expect(
          textOf('Ada <ada@zedu.chat> wrote'),
          'Ada <ada@zedu.chat> wrote',
        );
        expect(textOf('<T> is a generic type'), '<T> is a generic type');
      },
    );
  });

  group('system notices', () {
    const joinNotice =
        '<p><span class="mention" data-type="mention" data-id="u-1" '
        'data-label="mimi" data-mention-suggestion-char="@">@mimi</span> '
        'joined this channel. <span class="mention" data-type="mention" '
        'data-id="u-2" data-label="ada_l" '
        'data-mention-suggestion-char="@">@ada_l</span> and 5 others also '
        'joined.</p><p></p>';

    test('fromJson reads the type', () {
      final notice = ChannelMessage.fromJson({
        'thread_id': 't-1',
        'type': 'system',
        'message': joinNotice,
      });
      final message = ChannelMessage.fromJson({
        'thread_id': 't-2',
        'type': 'thread',
        'message': 'hi',
      });

      expect(notice.type, 'system');
      expect(notice.isSystem, isTrue);
      expect(message.isSystem, isFalse);
      expect(ChannelMessage.fromJson({'message': 'hi'}).isSystem, isFalse);
    });

    test('noticeParts splits out the named people without the @', () {
      final parts = ChannelMessage.fromJson({
        'type': 'system',
        'message': joinNotice,
      }).noticeParts;

      expect(
        [for (final p in parts) (p.text, p.isMention, p.userId)],
        [
          ('mimi', true, 'u-1'),
          (' joined this channel. ', false, null),
          ('ada_l', true, 'u-2'),
          (' and 5 others also joined.', false, null),
        ],
      );
    });

    test('noticeParts is the whole text when nobody is named', () {
      final parts = const ChannelMessage(
        senderName: 'system',
        text: 'Channel renamed',
      ).noticeParts;

      expect(parts.single.text, 'Channel renamed');
      expect(parts.single.isMention, isFalse);
    });
  });
}
