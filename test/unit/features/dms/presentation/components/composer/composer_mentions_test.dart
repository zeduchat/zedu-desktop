import 'package:zedu/features/features.dart';
import 'package:zedu/features/dms/presentation/components/composer/composer_mentions.dart';

import '../../../../../../helpers/helpers.dart';

Channel _channel(String name, {bool archived = false, bool hasAccess = true}) =>
    Channel(
      id: 'id-$name',
      name: name,
      description: '',
      organisationId: 'org-1',
      ownerId: 'user-1',
      archived: archived,
      hasAccess: hasAccess,
    );

final _ada = DmParticipant(
  userId: 'user-1',
  username: 'ada',
  email: 'ada@example.com',
);

void main() {
  group('mentionQueryBefore / channelQueryBefore', () {
    test('reads the query at the start or after a space only', () {
      expect(mentionQueryBefore('hi @Cha'), 'cha');
      expect(mentionQueryBefore('mail me@home'), isNull);
      expect(channelQueryBefore('see #Ge'), 'ge');
      expect(channelQueryBefore('#'), '');
      expect(channelQueryBefore('issue#12'), isNull);
    });
  });

  group('mentionSuggestionsFor', () {
    test('puts @channel first in a channel when the query matches', () {
      final list = mentionSuggestionsFor('cha', [_ada], isChannel: true);
      expect(list, hasLength(1));
      expect(isChannelMention(list.first), isTrue);

      final all = mentionSuggestionsFor('', [_ada], isChannel: true);
      expect(all.map((p) => p.username), ['channel', 'ada']);
    });

    test('never offers @channel in a DM', () {
      final list = mentionSuggestionsFor('cha', [_ada], isChannel: false);
      expect(list, isEmpty);
    });
  });

  group('channelSuggestionsFor', () {
    test('matches by name and leaves out archived and inaccessible', () {
      final list = channelSuggestionsFor('ge', [
        _channel('general'),
        _channel('random'),
        _channel('general-old', archived: true),
        _channel('general-left', hasAccess: false),
      ]);
      expect(list.map((c) => c.name), ['general']);
    });
  });

  group('composerMentionsIn', () {
    test('sends @channel the way web does, only in a channel', () {
      expect(
        composerMentionsIn(
          'heads up @channel',
          participants: [],
          isChannel: true,
        ),
        [
          {'type': 'user', 'id': channelMentionId},
        ],
      );
      expect(
        composerMentionsIn(
          'heads up @channel',
          participants: [],
          isChannel: false,
        ),
        isNull,
      );
      expect(
        composerMentionsIn('see @channels', participants: [], isChannel: true),
        isNull,
      );
    });

    test('sends a picked channel while its #name is in the text', () {
      expect(
        composerMentionsIn(
          'see #general and @ada',
          participants: [_ada],
          isChannel: true,
          pickedChannels: {'general': 'id-general'},
        ),
        [
          {'type': 'user', 'id': 'user-1'},
          {'type': 'channel', 'id': 'id-general', 'label': 'general'},
        ],
      );
      expect(
        composerMentionsIn(
          'see #generalist',
          participants: [],
          isChannel: true,
          pickedChannels: {'general': 'id-general'},
        ),
        isNull,
      );
    });

    test('records a mention followed by punctuation (#6341)', () {
      for (final text in [
        'thanks @ada',
        'thanks @ada.',
        '@ada. Next',
        'thanks @ada, see',
        'ping @ada!',
        'is it @ada?',
        '(@ada)',
      ]) {
        expect(
          composerMentionsIn(text, participants: [_ada], isChannel: false),
          [
            {'type': 'user', 'id': 'user-1'},
          ],
          reason: text,
        );
      }
    });

    test('a longer handle is not the shorter one', () {
      final lovelace = DmParticipant(
        userId: 'user-2',
        username: 'ada.lovelace',
        email: 'lovelace@example.com',
      );
      expect(
        composerMentionsIn(
          'hi @ada.lovelace',
          participants: [_ada],
          isChannel: false,
        ),
        isNull,
      );
      expect(
        composerMentionsIn(
          'hi @ada.lovelace.',
          participants: [_ada, lovelace],
          isChannel: false,
        ),
        [
          {'type': 'user', 'id': 'user-2'},
        ],
      );
      expect(
        composerMentionsIn('hi @ada-b', participants: [_ada], isChannel: false),
        isNull,
      );
    });

    test('@channel and a picked #channel can end a sentence', () {
      expect(
        composerMentionsIn(
          'heads up @channel. See #general.',
          participants: [],
          isChannel: true,
          pickedChannels: {'general': 'id-general'},
        ),
        [
          {'type': 'user', 'id': channelMentionId},
          {'type': 'channel', 'id': 'id-general', 'label': 'general'},
        ],
      );
    });
  });
}
