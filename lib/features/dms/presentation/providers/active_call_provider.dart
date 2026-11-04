import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

enum CallStatus { none, calling, incoming, active }

class ActiveCallState {
  final CallStatus status;
  final String? buzzId;
  final String? channelId;
  final String? remoteUserName;
  final String? remoteUserId;
  final String? remoteAvatarUrl;
  final String? token;
  final bool isFullPage;
  final DateTime? lastCallAt;

  const ActiveCallState({
    this.status = CallStatus.none,
    this.buzzId,
    this.channelId,
    this.remoteUserName,
    this.remoteUserId,
    this.remoteAvatarUrl,
    this.token,
    this.isFullPage = false,
    this.lastCallAt,
  });

  ActiveCallState copyWith({
    CallStatus? status,
    String? buzzId,
    String? channelId,
    String? remoteUserName,
    String? remoteUserId,
    String? remoteAvatarUrl,
    String? token,
    bool? isFullPage,
    DateTime? lastCallAt,
  }) {
    return ActiveCallState(
      status: status ?? this.status,
      buzzId: buzzId ?? this.buzzId,
      channelId: channelId ?? this.channelId,
      remoteUserName: remoteUserName ?? this.remoteUserName,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      remoteAvatarUrl: remoteAvatarUrl ?? this.remoteAvatarUrl,
      token: token ?? this.token,
      isFullPage: isFullPage ?? this.isFullPage,
      lastCallAt: lastCallAt ?? this.lastCallAt,
    );
  }
}

class ActiveCallNotifier extends Notifier<ActiveCallState> {
  static const Duration defaultRingTimeout = Duration(seconds: 30);

  /// How long an outgoing call rings before it is cancelled. A subclass may
  /// override it (the tests use a short ring to keep the suite fast).
  Duration get ringTimeout => defaultRingTimeout;

  StreamSubscription<Map<String, dynamic>>? _callEventsSub;
  Timer? _ringTimer;

  @override
  ActiveCallState build() {
    ref.onDispose(_cancelTimersAndSubscriptions);
    return const ActiveCallState();
  }

  void setFullPage(bool isFullPage) {
    state = state.copyWith(isFullPage: isFullPage);
  }

  Future<void> initiateCall({
    required String remoteUserId,
    required String remoteUserName,
    required String channelId,
    String? remoteAvatarUrl,
  }) async {
    _cancelTimersAndSubscriptions();
    state = ActiveCallState(
      status: CallStatus.calling,
      channelId: channelId,
      remoteUserId: remoteUserId,
      remoteUserName: remoteUserName,
      remoteAvatarUrl: remoteAvatarUrl,
      lastCallAt: DateTime.now(),
    );

    try {
      final repo = ref.read(buzzRepositoryProvider);
      final res = await repo.initiateDirectCall(remoteUserId);
      if (state.status != CallStatus.calling ||
          state.remoteUserId != remoteUserId) {
        return;
      }

      final buzzId = res['buzzId'] as String?;
      final token = res['token'] as String?;

      state = state.copyWith(buzzId: buzzId, token: token);

      _callEventsSub = repo.callEvents.listen(_handleCallSignal);
      _ringTimer = Timer(ringTimeout, () {
        if (state.status == CallStatus.calling && state.buzzId == buzzId) {
          unawaited(cancelCall());
        }
      });
    } catch (e) {
      endCall();
    }
  }

  void _handleCallSignal(Map<String, dynamic> event) {
    final Object? rawBuzzId =
        event['buzzId'] ?? event['buzz_id'] ?? event['id'];
    final String? eventBuzzId = rawBuzzId is String ? rawBuzzId : null;
    final Object? rawToken = event['token'];
    final String? token = rawToken is String ? rawToken : null;
    final String type =
        (event['type'] ?? event['event'] ?? event['status'] ?? '')
            .toString()
            .toLowerCase();

    if (type == 'accepted' ||
        type == 'accept' ||
        type == 'call_accepted' ||
        type == 'direct_call_accepted' ||
        type == 'buzz_accepted') {
      onRemoteCallAccepted(buzzId: eventBuzzId, token: token);
    } else if (type == 'declined' ||
        type == 'decline' ||
        type == 'rejected' ||
        type == 'reject' ||
        type == 'call_declined' ||
        type == 'direct_call_declined' ||
        type == 'ended' ||
        type == 'call_ended' ||
        type == 'buzz_ended' ||
        type == 'missed') {
      onRemoteCallDeclined(buzzId: eventBuzzId);
    }
  }

  void onRemoteCallAccepted({String? buzzId, String? token}) {
    if (state.status != CallStatus.calling) return;
    if (state.buzzId != null && buzzId != null && state.buzzId != buzzId) {
      return;
    }

    _ringTimer?.cancel();
    _ringTimer = null;
    state = state.copyWith(
      status: CallStatus.active,
      token: token ?? state.token,
    );
  }

  void onRemoteCallDeclined({String? buzzId}) {
    if (state.status != CallStatus.calling &&
        state.status != CallStatus.active) {
      return;
    }
    if (state.buzzId != null && buzzId != null && state.buzzId != buzzId) {
      return;
    }

    endCall();
  }

  void receiveIncomingCall({
    required String buzzId,
    required String remoteUserId,
    required String remoteUserName,
    required String channelId,
    String? remoteAvatarUrl,
  }) {
    if (state.status != CallStatus.none) {
      ref.read(buzzRepositoryProvider).respondToInvitation(buzzId, false);
      return;
    }

    state = ActiveCallState(
      status: CallStatus.incoming,
      buzzId: buzzId,
      channelId: channelId,
      remoteUserId: remoteUserId,
      remoteUserName: remoteUserName,
      remoteAvatarUrl: remoteAvatarUrl,
      isFullPage: false,
      lastCallAt: DateTime.now(),
    );
  }

  Future<void> acceptCall() async {
    if (state.status != CallStatus.incoming) return;

    if (state.buzzId != null) {
      await ref
          .read(buzzRepositoryProvider)
          .respondToInvitation(state.buzzId!, true);
      state = state.copyWith(
        status: CallStatus.active,
        token: 'mock-agora-token',
      );
    }
  }

  Future<void> declineCall() async {
    if (state.status != CallStatus.incoming) return;

    if (state.buzzId != null) {
      await ref
          .read(buzzRepositoryProvider)
          .respondToInvitation(state.buzzId!, false);
    }
    endCall();
  }

  Future<void> cancelCall() async {
    if (state.status != CallStatus.calling) return;

    final String? buzzId = state.buzzId;
    if (buzzId != null) {
      await ref.read(buzzRepositoryProvider).respondToDirectCall(buzzId, false);
    }
    endCall();
  }

  void endCall() {
    _cancelTimersAndSubscriptions();
    state = ActiveCallState(lastCallAt: state.lastCallAt);
  }

  void _cancelTimersAndSubscriptions() {
    _ringTimer?.cancel();
    _ringTimer = null;
    unawaited(_callEventsSub?.cancel());
    _callEventsSub = null;
  }
}

final activeCallProvider =
    NotifierProvider<ActiveCallNotifier, ActiveCallState>(
      ActiveCallNotifier.new,
    );
