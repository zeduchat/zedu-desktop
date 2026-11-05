import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ChatStorageService {
  final SecureStorageService _storage;
  final String? userId;
  final String? orgId;

  ChatStorageService(this._storage, {this.userId, this.orgId});

  String buildKey(String groupDmId, {String? userId, String? orgId}) {
    final effectiveUserId = userId ?? this.userId;
    final effectiveOrgId = orgId ?? this.orgId;
    if (effectiveUserId != null &&
        effectiveUserId.isNotEmpty &&
        effectiveOrgId != null &&
        effectiveOrgId.isNotEmpty) {
      return 'chat_messages_${effectiveUserId}_${effectiveOrgId}_$groupDmId';
    }
    return 'chat_messages_$groupDmId';
  }

  Future<void> saveMessages(
    String groupDmId,
    List<String> messages, {
    String? userId,
    String? orgId,
  }) async {
    final key = buildKey(groupDmId, userId: userId, orgId: orgId);
    await _storage.writeData(key, jsonEncode(messages));
  }

  Future<List<String>> getCachedMessages(
    String groupDmId, {
    String? userId,
    String? orgId,
  }) async {
    final key = buildKey(groupDmId, userId: userId, orgId: orgId);
    try {
      final data = await _storage.readData(key);
      if (data != null && data.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(data);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      debugPrint('Failed to parse cached chat messages for $key: $e');
    }
    return [];
  }

  Future<void> appendMessage(
    String groupDmId,
    String message, {
    String? userId,
    String? orgId,
  }) async {
    final messages = await getCachedMessages(
      groupDmId,
      userId: userId,
      orgId: orgId,
    );
    messages.add(message);
    await saveMessages(groupDmId, messages, userId: userId, orgId: orgId);
  }

  Future<void> clearCachedMessages(
    String groupDmId, {
    String? userId,
    String? orgId,
  }) async {
    final key = buildKey(groupDmId, userId: userId, orgId: orgId);
    await _storage.deleteValue(key);
  }
}

final chatStorageProvider = Provider<ChatStorageService>((ref) {
  final user = ref.watch(authNotifierProvider).user;
  return ChatStorageService(
    locator<SecureStorageService>(),
    userId: user?.id,
    orgId: user?.currentOrg,
  );
});
