import 'package:zedu/features/features.dart';

/// The id web sends for an @channel mention: notify everyone in the channel.
const channelMentionId = '00000000-0000-0000-0000-000000000000';

/// The @channel entry offered first in a channel composer's mention list.
final channelMentionParticipant = DmParticipant(
  userId: channelMentionId,
  username: 'channel',
  email: '',
);

/// Whether [participant] is the @channel entry, not a person.
bool isChannelMention(DmParticipant participant) =>
    participant.userId == channelMentionId;

/// The @mention query being typed right before the caret in [before], or null
/// when there is none. Only at the start or after whitespace, so an email
/// address like "user@domain.com" is not read as a mention.
String? mentionQueryBefore(String before) =>
    RegExp(r'(?:^|\s)@(\w*)$').firstMatch(before)?.group(1)?.toLowerCase();

/// The #channel query being typed right before the caret in [before], or
/// null when there is none. Same rule as [mentionQueryBefore].
String? channelQueryBefore(String before) =>
    RegExp(r'(?:^|\s)#([\w-]*)$').firstMatch(before)?.group(1)?.toLowerCase();

/// People (and, in a channel, @channel first) matching [query], like web.
List<DmParticipant> mentionSuggestionsFor(
  String query,
  List<DmParticipant> participants, {
  required bool isChannel,
}) {
  final people = participants.where((p) {
    return p.username.toLowerCase().contains(query) ||
        p.email.toLowerCase().contains(query);
  }).toList();
  final offerChannel = isChannel && 'channel'.contains(query);
  return offerChannel ? [channelMentionParticipant, ...people] : people;
}

/// Channels whose name matches [query], like web's # list. Archived
/// channels and ones the user can't open are left out.
List<Channel> channelSuggestionsFor(String query, List<Channel> channels) {
  return channels
      .where((c) => !c.archived && c.hasAccess)
      .where((c) => c.name.toLowerCase().contains(query))
      .toList();
}

/// The mentions [text] carries, in the shape the server reads, like the web
/// composer: people as `{type: user|bot, id}`, @channel as
/// `{type: user, id: channelMentionId}` and a picked channel as
/// `{type: channel, id, label}`. Null when there are none, so the request
/// leaves the field out.
List<Map<String, String>>? composerMentionsIn(
  String text, {
  required List<DmParticipant> participants,
  required bool isChannel,
  Map<String, String> pickedChannels = const {},
}) {
  final mentions = <Map<String, String>>[];
  final seen = <String>{};
  for (final participant in participants) {
    final username = participant.username.trim();
    if (participant.userId.isEmpty || username.isEmpty) continue;
    if (_hasToken(text, '@', username) && seen.add(participant.userId)) {
      mentions.add({
        'type': participant.userType == 'bot' ? 'bot' : 'user',
        'id': participant.userId,
      });
    }
  }
  if (isChannel &&
      _hasToken(text, '@', 'channel') &&
      seen.add(channelMentionId)) {
    mentions.add({'type': 'user', 'id': channelMentionId});
  }
  pickedChannels.forEach((name, id) {
    if (id.isEmpty || name.isEmpty) return;
    if (_hasToken(text, '#', name) && seen.add('channel:$id')) {
      mentions.add({'type': 'channel', 'id': id, 'label': name});
    }
  });
  return mentions.isEmpty ? null : mentions;
}

/// Whether [text] holds [prefix][name] as a whole token: not part of an
/// email or a longer handle. A `.` only continues the handle when a handle
/// character follows it, so a full stop can end the sentence (`thanks @ada.`)
/// while `@ada.lovelace` is still not `@ada`.
bool _hasToken(String text, String prefix, String name) => RegExp(
  '(?<![\\w@#.])${RegExp.escape(prefix)}${RegExp.escape(name)}'
  r'(?![\w-]|\.[\w-])',
  caseSensitive: false,
).hasMatch(text);
