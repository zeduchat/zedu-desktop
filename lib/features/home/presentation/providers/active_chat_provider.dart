import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

enum ActiveChatType {
  channel,
  groupDm,
  newGroupChat,
  directMessage,
  channelDirectory,
}

class ActiveChatState {
  final ActiveChatType type;
  final String? id;

  /// The id of the picked channel. Two channels can differ only in letter
  /// case, so the name in [id] alone cannot tell them apart.
  final String? channelId;

  const ActiveChatState({required this.type, this.id, this.channelId});

  static const generalChannel = ActiveChatState(
    type: ActiveChatType.channel,
    id: 'general',
  );
  static const newGroupChat = ActiveChatState(
    type: ActiveChatType.newGroupChat,
  );
  static const channelDirectory = ActiveChatState(
    type: ActiveChatType.channelDirectory,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveChatState &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id &&
          channelId == other.channelId;

  @override
  int get hashCode => Object.hash(type, id, channelId);
}

class ActiveChatNotifier extends Notifier<ActiveChatState> {
  @override
  ActiveChatState build() {
    // A channel picked in one workspace means nothing in another, so the
    // selection starts over when the workspace changes.
    ref.watch(workspaceProvider.select((s) => s.selectedWorkspace?.id));
    return ActiveChatState.generalChannel;
  }

  void selectChannel(String channelName, {String? channelId}) {
    state = ActiveChatState(
      type: ActiveChatType.channel,
      id: channelName,
      channelId: channelId,
    );
  }

  void selectGroupDm(String groupDmId) {
    state = ActiveChatState(type: ActiveChatType.groupDm, id: groupDmId);
  }

  void selectDirectMessage(String userId) {
    state = ActiveChatState(type: ActiveChatType.directMessage, id: userId);
  }

  void selectChannelDirectory() {
    state = ActiveChatState.channelDirectory;
  }

  void selectNewGroupChat() {
    state = ActiveChatState.newGroupChat;
  }
}

final activeChatProvider =
    NotifierProvider<ActiveChatNotifier, ActiveChatState>(
      ActiveChatNotifier.new,
    );
