import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

String formatDesktopWindowTitle({
  String? contextName,
  String? workspaceName,
  int unreadCount = 0,
  String appName = 'Zedu',
}) {
  final prefix = unreadCount > 0 ? '($unreadCount) ' : '';
  final trimmedContext = contextName?.trim();
  if (trimmedContext != null && trimmedContext.isNotEmpty) {
    return '$prefix$trimmedContext · $appName';
  }
  final trimmedWorkspace = workspaceName?.trim();
  if (trimmedWorkspace != null && trimmedWorkspace.isNotEmpty) {
    return '$prefix$trimmedWorkspace · $appName';
  }
  return appName;
}

String _formatChannelTitle(String name) {
  final clean = name.startsWith('#') ? name.substring(1).trim() : name.trim();
  if (clean.isEmpty) return 'General';
  return clean[0].toUpperCase() + clean.substring(1);
}

final desktopWindowTitleProvider = Provider<String>((ref) {
  final isAuthenticated = ref.watch(
    authNotifierProvider.select((s) => s.status == AuthStatus.authenticated),
  );
  if (!isAuthenticated) return 'Zedu';

  final workspace = ref.watch(
    workspaceProvider.select((s) => s.selectedWorkspace),
  );
  if (workspace == null) return 'Zedu';

  final activeChat = ref.watch(activeChatProvider);
  final channels = ref.watch(channelProvider).value ?? const [];
  final dms = ref.watch(dmListProvider).value ?? const [];
  final selectedDm = ref.watch(selectedDmProvider);

  String? contextName;
  switch (activeChat.type) {
    case ActiveChatType.channel:
      final ch = channels.firstWhere(
        (c) =>
            c.id == activeChat.id ||
            (activeChat.id == 'general' && c.name.toLowerCase() == 'general'),
        orElse: () => Channel(
          id: activeChat.id ?? 'general',
          name: activeChat.id == 'general' || activeChat.id == null
              ? 'General'
              : activeChat.id!,
          description: '',
          organisationId: workspace.id,
          isPrivate: false,
          ownerId: '',
        ),
      );
      contextName = _formatChannelTitle(ch.name);
      break;

    case ActiveChatType.directMessage:
      final dm = dms.firstWhere(
        (d) => d.participantId == activeChat.id || d.channelId == activeChat.id,
        orElse: () =>
            selectedDm ??
            DmConversation(
              channelId: activeChat.id ?? '',
              username: '',
              participantId: activeChat.id ?? '',
              previewMessage: '',
              unreadCount: 0,
            ),
      );
      contextName = dm.displayName != 'Unknown' && dm.displayName.isNotEmpty
          ? dm.displayName
          : (selectedDm?.displayName ?? activeChat.id);
      break;

    case ActiveChatType.groupDm:
      contextName = 'Group Chat';
      break;

    case ActiveChatType.channelDirectory:
      contextName = 'Channel Directory';
      break;

    case ActiveChatType.newGroupChat:
      contextName = 'New Group Chat';
      break;
  }

  int unreadCount = 0;
  for (final c in channels) {
    final isActive =
        activeChat.type == ActiveChatType.channel &&
        (c.id == activeChat.id ||
            (activeChat.id == 'general' && c.name.toLowerCase() == 'general'));
    if (!isActive) {
      unreadCount += c.unreadCount.toInt();
    }
  }

  for (final d in dms) {
    final isActive =
        activeChat.type == ActiveChatType.directMessage &&
        (d.participantId == activeChat.id || d.channelId == activeChat.id);
    if (!isActive) {
      unreadCount += d.unreadCount.toInt();
    }
  }

  return formatDesktopWindowTitle(
    contextName: contextName,
    workspaceName: workspace.name,
    unreadCount: unreadCount,
  );
});
