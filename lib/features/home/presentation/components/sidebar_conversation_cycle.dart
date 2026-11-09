import 'package:zedu/features/features.dart';

/// The conversations in the order the Home sidebar lists them: the channels
/// first, then the direct messages.
///
/// Mirrors what [SidebarChannelList] and [SidebarDmList] show: archived and
/// no-access channels and channels of another workspace are left out, as are
/// deleted DMs.
List<QuickSwitcherEntry> sidebarConversationOrder({
  required List<Channel> channels,
  required String? orgId,
  required List<DmConversation> dms,
  required DmConversationActions actions,
  required String? ownUserId,
}) {
  return [
    for (final channel in channels)
      if (!channel.archived &&
          channel.hasAccess &&
          (channel.organisationId.isEmpty || channel.organisationId == orgId))
        QuickSwitcherEntry.channel(channel.name, channelId: channel.id),
    for (final dm in homeSidebarDmOrder(
      dms,
      actions: actions,
      ownUserId: ownUserId,
    ))
      QuickSwitcherEntry.dm(dm),
  ];
}

/// The index in [entries] of the conversation that is open, or null when none
/// of them is (a settings page, the channel directory, a deleted DM).
///
/// [sidebar] says whether a channel or a DM is showing: a DM is open only on
/// the DMs tab, a channel only on Home.
int? openConversationIndex(
  List<QuickSwitcherEntry> entries, {
  required HomeSidebarType sidebar,
  required ActiveChatState chat,
  required DmConversation? selectedDm,
}) {
  if (sidebar == HomeSidebarType.dms) {
    final key = selectedDm?.conversationKey;
    if (key == null) return null;
    final index = entries.indexWhere(
      (e) => e.conversation?.conversationKey == key,
    );
    return index < 0 ? null : index;
  }
  if (sidebar != HomeSidebarType.home || chat.type != ActiveChatType.channel) {
    return null;
  }
  final pickedId = chat.channelId;
  final index = entries.indexWhere(
    (e) =>
        e.isChannel &&
        (pickedId != null
            ? e.channelId == pickedId
            : e.label.toLowerCase() == (chat.id ?? '').toLowerCase()),
  );
  return index < 0 ? null : index;
}

/// The conversation [step] places from the open one (-1 for the one above, 1
/// for the one below), or null at either end: the list does not wrap.
///
/// With nothing open, going down opens the first conversation and going up
/// does nothing.
QuickSwitcherEntry? adjacentConversation(
  List<QuickSwitcherEntry> entries,
  int? openIndex,
  int step,
) {
  if (entries.isEmpty) return null;
  if (openIndex == null) return step > 0 ? entries.first : null;
  final target = openIndex + step;
  if (target < 0 || target >= entries.length) return null;
  return entries[target];
}

/// The nearest conversation [step] places from the open one (-1 above, 1
/// below) that has unread messages, or null when there is none that way: the
/// list does not wrap.
///
/// A DM is unread when its own count says so; a channel is unread when its id
/// is in [unreadChannelIds]. With nothing open, going down gives the first
/// unread conversation and going up does nothing.
QuickSwitcherEntry? adjacentUnreadConversation(
  List<QuickSwitcherEntry> entries,
  int? openIndex,
  int step, {
  required Set<String> unreadChannelIds,
}) {
  bool isUnread(QuickSwitcherEntry entry) {
    final conversation = entry.conversation;
    if (conversation != null) return conversation.isUnread;
    return unreadChannelIds.contains(entry.channelId);
  }

  if (openIndex == null && step < 0) return null;
  var index = (openIndex ?? -1) + step;
  while (index >= 0 && index < entries.length) {
    if (isUnread(entries[index])) return entries[index];
    index += step;
  }
  return null;
}
