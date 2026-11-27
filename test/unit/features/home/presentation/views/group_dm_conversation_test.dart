import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('groupDmConversation (Ziki #2953)', () {
    final listed = DmConversation(
      channelId: 'g1',
      username: 'Ada, Tunde',
      participantId: '',
      channelType: 'group_dm',
      previewMessage: 'hi',
      unreadCount: 2,
    );
    const justCreated = GroupDM(id: 'g2', name: 'Chioma, Ife', members: []);

    test('uses the DMs list entry when the server lists the group', () {
      expect(
        groupDmConversation(
          'g1',
          conversations: [listed],
          groups: const [justCreated],
        ),
        same(listed),
      );
    });

    test('falls back to the group created in this session', () {
      final conversation = groupDmConversation(
        'g2',
        conversations: [listed],
        groups: const [justCreated],
      )!;
      expect(conversation.channelId, 'g2');
      expect(conversation.username, 'Chioma, Ife');
      expect(conversation.isGroup, isTrue);
    });

    test('is null for an unknown or empty id', () {
      expect(
        groupDmConversation('x', conversations: [listed], groups: const []),
        isNull,
      );
      expect(
        groupDmConversation('', conversations: null, groups: const []),
        isNull,
      );
    });
  });

  group('DmConversation.isGroup', () {
    for (final type in ['group_dm', 'groupdm', 'Group-DMs', 'GROUP_DM']) {
      test('$type is a group', () => expect(isGroupChannelType(type), isTrue));
    }
    for (final type in ['dm', 'channel', '']) {
      test('"$type" is not a group', () {
        expect(isGroupChannelType(type), isFalse);
      });
    }
  });
}
