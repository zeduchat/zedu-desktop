import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class GroupDM {
  final String id;
  final String name;
  final List<TeamMember> members;
  final int unreadCount;
  final List<String> messages;

  const GroupDM({
    required this.id,
    required this.name,
    required this.members,
    this.unreadCount = 0,
    this.messages = const [],
  });

  GroupDM copyWith({
    String? id,
    String? name,
    List<TeamMember>? members,
    int? unreadCount,
    List<String>? messages,
  }) {
    return GroupDM(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
      unreadCount: unreadCount ?? this.unreadCount,
      messages: messages ?? this.messages,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupDM &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          unreadCount == other.unreadCount;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ unreadCount.hashCode;
}

class GroupDmNotifier extends Notifier<List<GroupDM>> {
  final Map<String, List<String>> _offlineQueue = {};
  StreamSubscription<ChatWebsocketMessage>? _wsSubscription;

  /// Changes every time the provider is rebuilt (sign-out invalidates it, and
  /// the same notifier is reused for the next session). A delayed operation
  /// remembers the value it started with and gives up if it changed, so work
  /// begun in one session never lands in the next one's list.
  int _generation = 0;

  bool _isStale(int generation) => !ref.mounted || generation != _generation;

  @override
  List<GroupDM> build() {
    _generation++;
    _listenToWebsockets();
    _listenToNetwork();
    return [];
  }

  void _listenToWebsockets() {
    _wsSubscription?.cancel();
    final ws = ref.read(chatWebsocketProvider);
    _wsSubscription = ws.messageStream.listen((msg) {
      if (!ref.mounted) return;
      _handleIncomingMessage(msg.groupDmId, msg.text);
    });
    ref.onDispose(() {
      _wsSubscription?.cancel();
      _wsSubscription = null;
    });
  }

  void _listenToNetwork() {
    ref.listen<NetworkStatus>(networkStatusProvider, (previous, next) {
      if (next == NetworkStatus.online) {
        _flushOfflineQueue();
      }
    });
  }

  void _handleIncomingMessage(String groupId, String text) {
    if (!ref.mounted) return;
    state = [
      for (final group in state)
        if (group.id == groupId)
          group.copyWith(
            messages: [...group.messages, text],
            unreadCount: group.unreadCount + 1,
          )
        else
          group,
    ];
  }

  Future<Result<GroupDM>> createGroupDm(
    List<TeamMember> selectedMembers,
  ) async {
    final generation = _generation;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (_isStale(generation)) {
      return Failure<GroupDM>(
        const ApiFailure(
          message: 'Your session changed before the group was created.',
        ),
      );
    }

    final selectedIds = selectedMembers.map((m) => m.id).toSet();
    for (final group in state) {
      final groupIds = group.members.map((m) => m.id).toSet();
      if (groupIds.length == selectedIds.length &&
          groupIds.containsAll(selectedIds)) {
        return Success(group);
      }
    }

    final name = selectedMembers
        .map((m) => m.name ?? m.email.split('@').first)
        .join(', ');

    final newGroup = GroupDM(
      id: 'group-dm-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      members: selectedMembers,
      unreadCount: 0,
      messages: ['Group DM created with $name.'],
    );

    state = [...state, newGroup];

    // Tell websocket we are in this group now
    final activeIds = state.map((g) => g.id).toList();
    ref.read(chatWebsocketProvider).connect(activeIds);

    return Success(newGroup);
  }

  Future<void> sendMessage(String groupDmId, String messageText) async {
    final network = ref.read(networkStatusProvider);

    if (network == NetworkStatus.offline) {
      _offlineQueue.putIfAbsent(groupDmId, () => <String>[]).add(messageText);
      _appendMessage(groupDmId, _pendingLabel(messageText));
      return;
    }

    final generation = _generation;
    // Simulate API delay
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_isStale(generation)) return;

    _appendMessage(groupDmId, messageText);
    await _persistMessage(groupDmId, messageText);
  }

  Future<void> _flushOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;

    final queued = <String, List<String>>{
      for (final entry in _offlineQueue.entries)
        entry.key: List<String>.of(entry.value),
    };
    _offlineQueue.clear();

    for (final entry in queued.entries) {
      for (final messageText in entry.value) {
        try {
          // Simulate API delay
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await _persistMessage(entry.key, messageText);
          _replacePending(entry.key, messageText);
        } catch (error) {
          // Leave the message queued so the next reconnect retries it.
          _offlineQueue
              .putIfAbsent(entry.key, () => <String>[])
              .add(messageText);
          debugPrint('Could not flush a queued message: $error');
        }
      }
    }
  }

  Future<void> _persistMessage(String groupDmId, String messageText) async {
    await ref.read(chatStorageProvider).appendMessage(groupDmId, messageText);
  }

  void _appendMessage(String groupDmId, String messageText) {
    state = [
      for (final group in state)
        if (group.id == groupDmId)
          group.copyWith(messages: [...group.messages, messageText])
        else
          group,
    ];
  }

  void _replacePending(String groupDmId, String messageText) {
    final pending = _pendingLabel(messageText);
    state = [
      for (final group in state)
        if (group.id == groupDmId)
          group.copyWith(
            messages: _replaceFirst(group.messages, pending, messageText),
          )
        else
          group,
    ];
  }

  String _pendingLabel(String messageText) => '$messageText (Pending...)';

  List<String> _replaceFirst(List<String> messages, String from, String to) {
    final index = messages.indexOf(from);
    if (index == -1) return messages;
    return [
      for (var i = 0; i < messages.length; i++)
        if (i == index) to else messages[i],
    ];
  }

  void renameGroupDm(String groupId, String newName) {
    state = [
      for (final group in state)
        if (group.id == groupId) group.copyWith(name: newName) else group,
    ];
  }
}

final groupDmProvider = NotifierProvider<GroupDmNotifier, List<GroupDM>>(
  GroupDmNotifier.new,
);
