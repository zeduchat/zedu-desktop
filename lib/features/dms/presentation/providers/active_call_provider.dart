import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Where a call is. A call goes `none` → `calling` (outgoing, ringing the
/// other person) or `incoming` (ringing here) → `connecting` → `active`
/// (`reconnecting` while the link recovers) → `ended`.
enum CallStatus {
  none,
  calling,
  incoming,
  connecting,
  active,
  reconnecting,
  ended,
}

/// Why a call ended.
enum CallEndReason {
  /// This user left; the others may still be in the call.
  left,

  /// This user ended the call for everyone.
  endedForAll,

  /// The other person left or hung up.
  remoteLeft,

  /// This user declined an incoming call.
  declined,

  /// The person called declined.
  remoteDeclined,

  /// This user stopped ringing before anyone answered.
  canceled,

  /// The caller stopped ringing before this user answered.
  remoteCanceled,

  /// Nobody answered this user's call in time.
  noAnswer,

  /// This user didn't answer an incoming call in time.
  missed,

  /// Starting, joining or keeping the call failed.
  failed,

  /// Calls don't work on this platform (Linux).
  unsupported,
}

/// Someone in the call, other than this user.
class CallParticipant {
  const CallParticipant({
    required this.userId,
    required this.name,
    this.avatarUrl = '',
    this.hasVideo = false,
  });

  final String userId;
  final String name;
  final String avatarUrl;
  final bool hasVideo;

  CallParticipant copyWith({bool? hasVideo}) => CallParticipant(
    userId: userId,
    name: name,
    avatarUrl: avatarUrl,
    hasVideo: hasVideo ?? this.hasVideo,
  );
}

const Object _unset = Object();

/// The one source of truth for the current call.
class ActiveCallState {
  const ActiveCallState({
    this.status = CallStatus.none,
    this.isOutgoing = false,
    this.buzzId,
    this.channelId,
    this.remoteUserName,
    this.remoteUserId,
    this.remoteAvatarUrl,
    this.token,
    this.hostId,
    this.isFullPage = false,
    this.lastCallAt,
    this.connectedAt,
    this.endReason,
    this.errorMessage,
    this.isMicMuted = false,
    this.isCameraOn = false,
    this.isSharingScreen = false,
    this.sharedSourceName,
    this.remoteScreenSharerId,
    this.participants = const [],
    this.activeSpeakerId,
    this.networkQuality = BuzzNetworkQuality.unknown,
  });

  final CallStatus status;

  /// Whether this user started the call.
  final bool isOutgoing;
  final String? buzzId;

  /// The DM channel the call belongs to.
  final String? channelId;
  final String? remoteUserName;
  final String? remoteUserId;
  final String? remoteAvatarUrl;

  /// The Agora token the call was joined with.
  final String? token;
  final String? hostId;
  final bool isFullPage;
  final DateTime? lastCallAt;

  /// When the call became active, for the call timer.
  final DateTime? connectedAt;
  final CallEndReason? endReason;

  /// A message to show the user when the call failed or isn't supported.
  final String? errorMessage;
  final bool isMicMuted;
  final bool isCameraOn;
  final bool isSharingScreen;

  /// The screen or window this user is sharing.
  final String? sharedSourceName;

  /// The user id of whoever else is sharing their screen.
  final String? remoteScreenSharerId;
  final List<CallParticipant> participants;

  /// The user id of the loudest speaker: this user's id when it's them.
  final String? activeSpeakerId;
  final BuzzNetworkQuality networkQuality;

  bool get isInCall =>
      status == CallStatus.connecting ||
      status == CallStatus.active ||
      status == CallStatus.reconnecting;

  bool get isBusy => status != CallStatus.none && status != CallStatus.ended;

  ActiveCallState copyWith({
    CallStatus? status,
    bool? isOutgoing,
    String? buzzId,
    String? channelId,
    String? remoteUserName,
    String? remoteUserId,
    String? remoteAvatarUrl,
    String? token,
    String? hostId,
    bool? isFullPage,
    DateTime? lastCallAt,
    Object? connectedAt = _unset,
    Object? endReason = _unset,
    Object? errorMessage = _unset,
    bool? isMicMuted,
    bool? isCameraOn,
    bool? isSharingScreen,
    Object? sharedSourceName = _unset,
    Object? remoteScreenSharerId = _unset,
    List<CallParticipant>? participants,
    Object? activeSpeakerId = _unset,
    BuzzNetworkQuality? networkQuality,
  }) {
    return ActiveCallState(
      status: status ?? this.status,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      buzzId: buzzId ?? this.buzzId,
      channelId: channelId ?? this.channelId,
      remoteUserName: remoteUserName ?? this.remoteUserName,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      remoteAvatarUrl: remoteAvatarUrl ?? this.remoteAvatarUrl,
      token: token ?? this.token,
      hostId: hostId ?? this.hostId,
      isFullPage: isFullPage ?? this.isFullPage,
      lastCallAt: lastCallAt ?? this.lastCallAt,
      connectedAt: identical(connectedAt, _unset)
          ? this.connectedAt
          : connectedAt as DateTime?,
      endReason: identical(endReason, _unset)
          ? this.endReason
          : endReason as CallEndReason?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isSharingScreen: isSharingScreen ?? this.isSharingScreen,
      sharedSourceName: identical(sharedSourceName, _unset)
          ? this.sharedSourceName
          : sharedSourceName as String?,
      remoteScreenSharerId: identical(remoteScreenSharerId, _unset)
          ? this.remoteScreenSharerId
          : remoteScreenSharerId as String?,
      participants: participants ?? this.participants,
      activeSpeakerId: identical(activeSpeakerId, _unset)
          ? this.activeSpeakerId
          : activeSpeakerId as String?,
      networkQuality: networkQuality ?? this.networkQuality,
    );
  }
}

/// Runs direct Buzz calls: the Buzz endpoints through [buzzRepositoryProvider],
/// media through [buzzCallServiceProvider] and server signals through
/// [callSignalingProvider].
class ActiveCallNotifier extends ChangeNotifier {
  /// Kept for existing callers; the ring timeout is [kBuzzRingTimeout].
  static const Duration defaultRingTimeout = kBuzzRingTimeout;

  final Ref _ref;
  final Duration ringTimeout;
  ActiveCallState _state = const ActiveCallState();
  Timer? _ringTimer;
  StreamSubscription<CallSignal>? _signalSub;
  StreamSubscription<BuzzCallEvent>? _mediaSub;

  /// The media service while a call holds it, so every exit can release it.
  BuzzCallService? _media;
  bool _disposed = false;

  /// Bumped whenever a call starts or ends, so the replies of an older call's
  /// requests are ignored.
  int _attempt = 0;

  /// Agora uid → user account (user id), for the people in the call channel.
  final Map<int, String> _remoteAccounts = {};

  /// Agora uids currently in the call channel (not the screen channel).
  final Set<int> _remoteUids = {};

  /// The people the server listed for the call, to name the tiles.
  Map<String, BuzzCallParticipant> _knownParticipants = {};

  ActiveCallNotifier(this._ref, {this.ringTimeout = kBuzzRingTimeout}) {
    _signalSub = _ref.read(callSignalingProvider).signals.listen(_onSignal);
  }

  ActiveCallState get state => _state;
  bool get isDisposed => _disposed;

  /// The ringtone playing for the current incoming call, or null.
  CallRingtone? _ringing;

  BuzzCallRepository get _repo => _ref.read(buzzRepositoryProvider);

  String get _myUserId => _ref.read(authNotifierProvider).user?.id ?? '';

  @override
  void notifyListeners() {
    if (_disposed) return;
    _syncRingtone();
    super.notifyListeners();
  }

  void _set(ActiveCallState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  /// Rings while a call is coming in and stops on any other state: accepted,
  /// declined, cancelled by the caller, timed out or ended. Stays silent while
  /// notifications are paused.
  void _syncRingtone() {
    final shouldRing =
        _state.status == CallStatus.incoming &&
        !_ref.read(notificationSettingsProvider).isDndActive;
    if (shouldRing == (_ringing != null)) return;
    if (shouldRing) {
      final ringtone = _ref.read(callRingtoneProvider);
      _ringing = ringtone;
      unawaited(ringtone.start());
    } else {
      final ringtone = _ringing!;
      _ringing = null;
      unawaited(ringtone.stop());
    }
  }

  void setFullPage(bool isFullPage) {
    _set(_state.copyWith(isFullPage: isFullPage));
  }

  // ── Starting and answering ────────────────────────────────────────────────

  /// Calls the other person in the DM [channelId]: creates the call, joins it
  /// and rings until they join the media channel, decline or time out.
  Future<void> initiateCall({
    required String remoteUserId,
    required String remoteUserName,
    required String channelId,
    String? remoteAvatarUrl,
    bool withVideo = false,
  }) async {
    if (_disposed || _state.isBusy) return;
    final attempt = _beginAttempt();
    _set(
      ActiveCallState(
        status: CallStatus.calling,
        isOutgoing: true,
        channelId: channelId,
        remoteUserId: remoteUserId,
        remoteUserName: remoteUserName,
        remoteAvatarUrl: remoteAvatarUrl,
        isCameraOn: withVideo,
        lastCallAt: DateTime.now(),
      ),
    );
    if (!_ref.read(buzzCallServiceProvider).isSupported) {
      _finish(CallEndReason.unsupported, message: _unsupportedMessage);
      return;
    }
    _startRingTimer(attempt);

    final started = await _repo.startDirectCall(channelId);
    if (!_isCurrent(attempt)) {
      // Cancelled while the call was being created: stop it ringing.
      if (started case Success<DirectCall>(:final value)) {
        unawaited(_repo.respond(_buzzIdOf(value), BuzzCallResponse.cancel));
      }
      return;
    }
    final DirectCall call;
    switch (started) {
      case Success<DirectCall>(:final value):
        call = value;
      case Failure<DirectCall>(:final error):
        _finish(CallEndReason.failed, message: error.friendlyMessage);
        return;
    }
    _set(_state.copyWith(buzzId: call.buzzId.isNotEmpty ? call.buzzId : null));

    final joined = await _repo.join(call.joinId);
    if (!_isCurrent(attempt)) {
      // Cancelled while joining: make sure the other side stops ringing.
      unawaited(_repo.respond(_buzzIdOf(call), BuzzCallResponse.cancel));
      return;
    }
    switch (joined) {
      case Success<BuzzSession>(:final value):
        await _connectMedia(attempt, value, withVideo: withVideo);
      case Failure<BuzzSession>(:final error):
        unawaited(_repo.respond(_buzzIdOf(call), BuzzCallResponse.cancel));
        _finish(CallEndReason.failed, message: error.friendlyMessage);
    }
  }

  /// Shows a call someone else started. Declines it straight away when this
  /// user is already in or ringing on another call.
  void receiveIncomingCall({
    required String buzzId,
    required String remoteUserId,
    required String remoteUserName,
    required String channelId,
    String? remoteAvatarUrl,
  }) {
    if (_disposed) return;
    if (_state.isBusy) {
      if (_state.buzzId != buzzId) {
        unawaited(_repo.respond(buzzId, BuzzCallResponse.decline));
      }
      return;
    }
    final attempt = _beginAttempt();
    _set(
      ActiveCallState(
        status: CallStatus.incoming,
        buzzId: buzzId,
        channelId: channelId,
        remoteUserId: remoteUserId,
        remoteUserName: remoteUserName,
        remoteAvatarUrl: remoteAvatarUrl,
        lastCallAt: DateTime.now(),
      ),
    );
    _startRingTimer(attempt);
  }

  /// Answers the incoming call and joins it.
  Future<void> acceptCall({bool withVideo = false}) async {
    if (_disposed || _state.status != CallStatus.incoming) return;
    final buzzId = _state.buzzId;
    if (buzzId == null) return;
    final attempt = _attempt;
    _ringTimer?.cancel();
    if (!_ref.read(buzzCallServiceProvider).isSupported) {
      unawaited(_repo.respond(buzzId, BuzzCallResponse.decline));
      _finish(CallEndReason.unsupported, message: _unsupportedMessage);
      return;
    }
    _set(_state.copyWith(status: CallStatus.connecting, isCameraOn: withVideo));

    final answered = await _repo.respond(buzzId, BuzzCallResponse.accept);
    if (!_isCurrent(attempt)) return;
    final String joinId;
    switch (answered) {
      case Success<DirectCall>(:final value):
        joinId = value.joinId.isNotEmpty ? value.joinId : buzzId;
      case Failure<DirectCall>(:final error):
        _finish(CallEndReason.failed, message: error.friendlyMessage);
        return;
    }

    final joined = await _repo.join(joinId);
    if (!_isCurrent(attempt)) return;
    switch (joined) {
      case Success<BuzzSession>(:final value):
        await _connectMedia(attempt, value, withVideo: withVideo);
      case Failure<BuzzSession>(:final error):
        _finish(CallEndReason.failed, message: error.friendlyMessage);
    }
  }

  Future<void> declineCall() async {
    if (_disposed || _state.status != CallStatus.incoming) return;
    final buzzId = _state.buzzId;
    _finish(CallEndReason.declined);
    if (buzzId != null) {
      await _repo.respond(buzzId, BuzzCallResponse.decline);
    }
  }

  // ── Hanging up ────────────────────────────────────────────────────────────

  /// Stops ringing an outgoing call before anyone answers.
  Future<void> cancelCall() async {
    if (_disposed || _state.status != CallStatus.calling) return;
    final buzzId = _state.buzzId;
    await _releaseMedia();
    _finish(CallEndReason.canceled);
    if (buzzId != null) {
      await _repo.respond(buzzId, BuzzCallResponse.cancel);
    }
  }

  /// Leaves the call; it carries on for anyone else still in it. When nobody
  /// else is left, the call is ended too, as the web app does.
  Future<void> leaveCall() =>
      _hangUp(CallEndReason.left, endForEveryone: _remoteUids.isEmpty);

  /// Ends the call for everyone in it.
  Future<void> endCallForEveryone() =>
      _hangUp(CallEndReason.endedForAll, endForEveryone: true);

  /// The hang-up button: cancels a ringing call, declines an incoming one and
  /// leaves one in progress.
  Future<void> endCall() async {
    switch (_state.status) {
      case CallStatus.calling:
        await cancelCall();
      case CallStatus.incoming:
        await declineCall();
      case CallStatus.connecting:
      case CallStatus.active:
      case CallStatus.reconnecting:
        await leaveCall();
      case CallStatus.none:
      case CallStatus.ended:
        break;
    }
  }

  Future<void> _hangUp(
    CallEndReason reason, {
    required bool endForEveryone,
  }) async {
    if (_disposed || !_state.isInCall) return;
    final buzzId = _state.buzzId;
    await _releaseMedia();
    _finish(reason);
    if (buzzId == null) return;
    if (endForEveryone && reason == CallEndReason.endedForAll) {
      await _repo.end(buzzId);
      return;
    }
    await _repo.leave(buzzId);
    if (endForEveryone) await _repo.end(buzzId);
  }

  // ── In the call ───────────────────────────────────────────────────────────

  Future<void> setMicrophoneMuted(bool muted) async {
    if (_disposed || !_state.isInCall || _media == null) return;
    final previous = _state.isMicMuted;
    _set(_state.copyWith(isMicMuted: muted));
    try {
      await _media!.setMicrophoneMuted(muted);
    } catch (error) {
      AppLogger.w('Could not change the microphone', error: error);
      _set(_state.copyWith(isMicMuted: previous));
    }
  }

  Future<void> toggleMicrophone() => setMicrophoneMuted(!_state.isMicMuted);

  Future<void> setCameraEnabled(bool enabled) async {
    if (_disposed || !_state.isInCall || _media == null) return;
    final previous = _state.isCameraOn;
    _set(_state.copyWith(isCameraOn: enabled));
    try {
      await _media!.setCameraEnabled(enabled);
    } catch (error) {
      AppLogger.w('Could not change the camera', error: error);
      _set(_state.copyWith(isCameraOn: previous));
    }
  }

  Future<void> toggleCamera() => setCameraEnabled(!_state.isCameraOn);

  /// The screens and windows this user can share, or none outside a call.
  Future<List<BuzzScreenSource>> screenSources() async {
    final media = _media;
    if (_disposed || _state.status != CallStatus.active || media == null) {
      return const [];
    }
    try {
      return await media.screenSources();
    } catch (error) {
      AppLogger.w('Could not list screens and windows', error: error);
      return const [];
    }
  }

  /// Shares [source]. Returns false, with [ActiveCallState.errorMessage] set,
  /// when sharing couldn't start.
  Future<bool> startScreenShare(BuzzScreenSource source) async {
    final media = _media;
    if (_disposed || _state.status != CallStatus.active || media == null) {
      return false;
    }
    try {
      await media.startScreenShare(source);
    } catch (error) {
      AppLogger.w('Could not start screen sharing', error: error);
      _set(
        _state.copyWith(
          isSharingScreen: false,
          sharedSourceName: null,
          errorMessage: "Couldn't start sharing your screen.",
        ),
      );
      return false;
    }
    _set(
      _state.copyWith(
        isSharingScreen: true,
        sharedSourceName: source.name,
        errorMessage: null,
      ),
    );
    return true;
  }

  Future<void> stopScreenShare() async {
    final media = _media;
    if (_disposed || !_state.isSharingScreen || media == null) return;
    try {
      await media.stopScreenShare();
    } catch (error) {
      AppLogger.w('Could not stop screen sharing', error: error);
    }
    _set(_state.copyWith(isSharingScreen: false, sharedSourceName: null));
  }

  /// The screen someone else is sharing, or null when nobody else shares.
  Widget? remoteScreenView() {
    final sharer = _state.remoteScreenSharerId;
    final media = _media;
    if (_disposed || sharer == null || media == null) return null;
    final account = buzzScreenShareAccount(sharer);
    for (final entry in _remoteAccounts.entries) {
      if (entry.value == account) return media.remoteScreenView(entry.key);
    }
    return null;
  }

  /// Sends one of [kBuzzQuickReactions]. Returns whether the server took it.
  Future<bool> sendReaction(String emoji) async {
    final buzzId = _state.buzzId;
    if (_disposed || _state.status != CallStatus.active || buzzId == null) {
      return false;
    }
    final result = await _repo.sendReaction(buzzId, emoji);
    return result is Success<void>;
  }

  // ── Media ────────────────────────────────────────────────────────────────

  Future<void> _connectMedia(
    int attempt,
    BuzzSession session, {
    required bool withVideo,
  }) async {
    final media = _ref.read(buzzCallServiceProvider);
    _knownParticipants = {
      for (final p in session.participants)
        if (p.userId.isNotEmpty) p.userId: p,
    };
    _set(
      _state.copyWith(
        buzzId: session.buzzId.isNotEmpty ? session.buzzId : null,
        hostId: session.hostId.isNotEmpty ? session.hostId : null,
        token: session.agora.token,
      ),
    );
    _media = media;
    _mediaSub = media.events.listen((event) => _onMediaEvent(attempt, event));
    try {
      await media.initialize(session.agora.appId);
      if (!_isCurrent(attempt)) return;
      await media.joinCall(
        token: session.agora.token,
        channelId: session.agora.channelName.isNotEmpty
            ? session.agora.channelName
            : _state.buzzId ?? session.buzzId,
        userAccount: session.agora.uid,
        withVideo: withVideo,
      );
    } catch (error) {
      AppLogger.e('Could not join the call', error: error);
      if (!_isCurrent(attempt)) return;
      await _failInCall(attempt, "Couldn't connect the call.");
    }
  }

  /// Joins `screen-<buzz_id>` as `screen-<user id>` so others' shares show up
  /// and this user can share. A failure only disables sharing.
  Future<void> _joinScreenChannel(int attempt) async {
    final buzzId = _state.buzzId;
    final media = _media;
    final me = _myUserId;
    if (buzzId == null || media == null || me.isEmpty) return;
    final account = buzzScreenShareAccount(me);
    final result = await _repo.token(buzzId: buzzId, uid: account);
    if (!_isCurrent(attempt)) return;
    switch (result) {
      case Success<BuzzAgoraCredentials>(:final value):
        try {
          await media.joinScreenChannel(
            token: value.token,
            channelId: value.channelName.isNotEmpty
                ? value.channelName
                : buzzScreenShareChannel(buzzId),
            userAccount: value.uid,
          );
        } catch (error) {
          AppLogger.w('Could not join the screen-share channel', error: error);
        }
      case Failure<BuzzAgoraCredentials>(:final error):
        AppLogger.w('No screen-share token', error: error);
    }
  }

  void _onMediaEvent(int attempt, BuzzCallEvent event) {
    if (!_isCurrent(attempt)) return;
    switch (event) {
      case BuzzJoined(:final channel):
        if (channel != BuzzChannel.call) return;
        if (!_state.isOutgoing) {
          _set(
            _state.copyWith(
              status: CallStatus.active,
              connectedAt: DateTime.now(),
            ),
          );
        }
        unawaited(_joinScreenChannel(attempt));
      case BuzzRemoteJoined(:final channel, :final remoteUid):
        if (channel != BuzzChannel.call) return;
        _remoteUids.add(remoteUid);
        if (_state.status == CallStatus.calling ||
            _state.status == CallStatus.connecting) {
          _ringTimer?.cancel();
          _set(
            _state.copyWith(
              status: CallStatus.active,
              connectedAt: _state.connectedAt ?? DateTime.now(),
            ),
          );
        }
        _syncParticipants();
      case BuzzRemoteLeft(:final channel, :final remoteUid):
        if (channel == BuzzChannel.screen) {
          if (_state.remoteScreenSharerId != null &&
              _accountOf(remoteUid) ==
                  buzzScreenShareAccount(_state.remoteScreenSharerId!)) {
            _set(_state.copyWith(remoteScreenSharerId: null));
          }
          return;
        }
        _remoteUids.remove(remoteUid);
        _syncParticipants();
        if (_remoteUids.isEmpty && _state.status != CallStatus.calling) {
          unawaited(_remoteHungUp(attempt));
        }
      case BuzzRemoteIdentified(:final remoteUid, :final userAccount):
        _remoteAccounts[remoteUid] = userAccount;
        _syncParticipants();
      case BuzzRemoteVideoChanged(
        :final channel,
        :final remoteUid,
        :final isOn,
      ):
        _onRemoteVideo(channel, remoteUid, isOn);
      case BuzzLinkChanged(:final channel, :final state):
        if (channel == BuzzChannel.call) _onLinkChanged(attempt, state);
      case BuzzActiveSpeaker(:final uid):
        final String? speaker = uid == null
            ? null
            : uid == 0
            ? _myUserId
            : _accountOf(uid);
        if (speaker != _state.activeSpeakerId) {
          _set(_state.copyWith(activeSpeakerId: speaker));
        }
      case BuzzQualityChanged(:final quality):
        if (quality != _state.networkQuality) {
          _set(_state.copyWith(networkQuality: quality));
        }
      case BuzzEngineError(:final message):
        AppLogger.w('Call engine error: $message');
        if (_state.status == CallStatus.connecting) {
          unawaited(_failInCall(attempt, "Couldn't connect the call."));
        }
    }
  }

  void _onRemoteVideo(BuzzChannel channel, int remoteUid, bool isOn) {
    final account = _accountOf(remoteUid);
    if (account == null) return;
    if (channel == BuzzChannel.screen) {
      if (!isBuzzScreenShareAccount(account)) return;
      final sharer = account.substring('screen-'.length);
      if (sharer == _myUserId) return;
      if (isOn) {
        _set(_state.copyWith(remoteScreenSharerId: sharer));
      } else if (_state.remoteScreenSharerId == sharer) {
        _set(_state.copyWith(remoteScreenSharerId: null));
      }
      return;
    }
    _set(
      _state.copyWith(
        participants: [
          for (final p in _state.participants)
            p.userId == account ? p.copyWith(hasVideo: isOn) : p,
        ],
      ),
    );
  }

  void _onLinkChanged(int attempt, BuzzLinkState link) {
    switch (link) {
      case BuzzLinkState.reconnecting:
        if (_state.status == CallStatus.active) {
          _set(_state.copyWith(status: CallStatus.reconnecting));
        }
      case BuzzLinkState.connected:
        if (_state.status == CallStatus.reconnecting) {
          _set(_state.copyWith(status: CallStatus.active));
        }
      case BuzzLinkState.failed:
        unawaited(_failInCall(attempt, 'The call lost its connection.'));
      case BuzzLinkState.connecting:
      case BuzzLinkState.disconnected:
        break;
    }
  }

  /// The other person left or dropped: leave too, ending the empty call.
  Future<void> _remoteHungUp(int attempt) async {
    if (!_isCurrent(attempt) || !_state.isInCall) return;
    final buzzId = _state.buzzId;
    await _releaseMedia();
    _finish(CallEndReason.remoteLeft);
    if (buzzId == null) return;
    await _repo.leave(buzzId);
    await _repo.end(buzzId);
  }

  Future<void> _failInCall(int attempt, String message) async {
    if (!_isCurrent(attempt)) return;
    final buzzId = _state.buzzId;
    final wasRinging = _state.status == CallStatus.calling;
    await _releaseMedia();
    _finish(CallEndReason.failed, message: message);
    if (buzzId == null) return;
    if (wasRinging) {
      await _repo.respond(buzzId, BuzzCallResponse.cancel);
    } else {
      await _repo.leave(buzzId);
    }
  }

  String? _accountOf(int uid) => _remoteAccounts[uid];

  /// Rebuilds the tiles from who is in the call channel right now.
  void _syncParticipants() {
    final previous = {for (final p in _state.participants) p.userId: p};
    final participants = <CallParticipant>[];
    for (final uid in _remoteUids) {
      final userId = _accountOf(uid);
      if (userId == null || isBuzzScreenShareAccount(userId)) continue;
      final known = _knownParticipants[userId];
      final isRemoteUser = userId == _state.remoteUserId;
      participants.add(
        CallParticipant(
          userId: userId,
          name: (known?.username.isNotEmpty ?? false)
              ? known!.username
              : isRemoteUser
              ? (_state.remoteUserName ?? '')
              : '',
          avatarUrl: (known?.effectiveAvatarUrl.isNotEmpty ?? false)
              ? known!.effectiveAvatarUrl
              : isRemoteUser
              ? (_state.remoteAvatarUrl ?? '')
              : '',
          hasVideo: previous[userId]?.hasVideo ?? false,
        ),
      );
    }
    _set(_state.copyWith(participants: participants));
  }

  // ── Signals from the server ───────────────────────────────────────────────

  void _onSignal(CallSignal signal) {
    if (_disposed) return;
    switch (signal) {
      case IncomingCallSignal():
        if (signal.callerId == _myUserId) return;
        receiveIncomingCall(
          buzzId: signal.buzzId,
          remoteUserId: signal.callerId,
          remoteUserName: signal.callerName,
          channelId: signal.channelId,
          remoteAvatarUrl: signal.avatarUrl.isNotEmpty
              ? signal.avatarUrl
              : null,
        );
      case CallResponseSignal():
        if (!_state.isOutgoing || signal.buzzId != _state.buzzId) return;
        if (_state.status != CallStatus.calling) return;
        if (signal.isDeclined) {
          unawaited(_endRinging(CallEndReason.remoteDeclined));
        } else if (signal.isTimedOut) {
          unawaited(_endRinging(CallEndReason.noAnswer));
        }
      // Accepted: the call turns active when they join the media channel.
      case CallCanceledSignal():
        if (_state.status == CallStatus.incoming &&
            signal.buzzId == _state.buzzId) {
          _finish(CallEndReason.remoteCanceled);
        }
    }
  }

  /// The other side declined or timed out while this user's call rang.
  Future<void> _endRinging(CallEndReason reason) async {
    await _releaseMedia();
    _finish(reason);
  }

  // ── Bookkeeping ───────────────────────────────────────────────────────────

  int _beginAttempt() {
    _ringTimer?.cancel();
    _remoteAccounts.clear();
    _remoteUids.clear();
    _knownParticipants = {};
    return ++_attempt;
  }

  bool _isCurrent(int attempt) => !_disposed && attempt == _attempt;

  String _buzzIdOf(DirectCall call) =>
      call.buzzId.isNotEmpty ? call.buzzId : call.buzzCode;

  void _startRingTimer(int attempt) {
    _ringTimer?.cancel();
    _ringTimer = Timer(ringTimeout, () {
      if (!_isCurrent(attempt)) return;
      final buzzId = _state.buzzId;
      if (_state.status == CallStatus.calling) {
        unawaited(() async {
          await _releaseMedia();
          _finish(CallEndReason.noAnswer);
          if (buzzId != null) {
            await _repo.respond(buzzId, BuzzCallResponse.cancel);
          }
        }());
      } else if (_state.status == CallStatus.incoming) {
        _finish(CallEndReason.missed);
        if (buzzId != null) {
          unawaited(_repo.respond(buzzId, BuzzCallResponse.timeout));
        }
      }
    });
  }

  /// Leaves the media channels and releases the engine. Every way out of a
  /// call goes through here.
  Future<void> _releaseMedia() async {
    final media = _media;
    _media = null;
    final sub = _mediaSub;
    _mediaSub = null;
    await sub?.cancel();
    if (media == null) return;
    try {
      await media.dispose();
    } catch (error) {
      AppLogger.w('Releasing the call engine failed', error: error);
    }
  }

  /// Ends the call locally: stops timers and leaves only what the UI needs.
  void _finish(CallEndReason reason, {String? message}) {
    _ringTimer?.cancel();
    _ringTimer = null;
    _attempt++;
    _remoteAccounts.clear();
    _remoteUids.clear();
    _set(
      ActiveCallState(
        status: CallStatus.ended,
        endReason: reason,
        errorMessage: message,
        buzzId: _state.buzzId,
        remoteUserName: _state.remoteUserName,
        remoteUserId: _state.remoteUserId,
        lastCallAt: _state.lastCallAt,
      ),
    );
  }

  static const String _unsupportedMessage =
      "Calls aren't available on Linux yet.";

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ringTimer?.cancel();
    _ringTimer = null;
    unawaited(_signalSub?.cancel());
    _signalSub = null;
    final media = _media;
    _media = null;
    unawaited(_mediaSub?.cancel());
    _mediaSub = null;
    if (media != null) unawaited(media.dispose());
    // The Ref can't be used while disposing, so stop the ringtone we hold.
    final ringtone = _ringing;
    _ringing = null;
    if (ringtone != null) unawaited(ringtone.stop());
    super.dispose();
  }
}

final activeCallProvider = ChangeNotifierProvider<ActiveCallNotifier>((ref) {
  return ActiveCallNotifier(ref);
});
