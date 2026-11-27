import 'dart:async';
import 'dart:io' show Platform;

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final buzzCallServiceProvider = Provider<BuzzCallService>((ref) {
  final service = AgoraBuzzCallService();
  ref.onDispose(() {
    unawaited(service.dispose().whenComplete(service.closeEvents));
  });
  return service;
});

/// Call signals. Nothing sends them until the Centrifugo client is approved;
/// override this provider with that client then.
final callSignalingProvider = Provider<CallSignaling>((ref) {
  return const NoCallSignaling();
});

/// [BuzzCallService] on the Agora RTC SDK. Users join with their user id as
/// an Agora *user account*, because the backend issues tokens for string ids
/// (and `screen-<user id>` for screen shares), not numeric uids.
class AgoraBuzzCallService implements BuzzCallService {
  AgoraBuzzCallService({RtcEngineEx Function()? createEngine})
    : _createEngine = createEngine ?? createAgoraRtcEngineEx;

  final RtcEngineEx Function() _createEngine;
  final StreamController<BuzzCallEvent> _events =
      StreamController<BuzzCallEvent>.broadcast();

  RtcEngineEx? _engine;
  RtcEngineEventHandler? _handler;
  String? _appId;
  String? _screenChannelId;
  RtcConnection? _screenConnection;
  bool _sharing = false;

  /// Below this Agora volume (0-255) nobody counts as speaking.
  static const int _speakingVolume = 30;

  @override
  bool get isSupported => Platform.isMacOS || Platform.isWindows;

  @override
  Stream<BuzzCallEvent> get events => _events.stream;

  @override
  Future<void> initialize(String appId) async {
    if (_engine != null && _appId == appId) return;
    if (_engine != null) await dispose();

    final engine = _createEngine();
    await engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    final handler = _buildHandler();
    engine.registerEventHandler(handler);
    await engine.enableVideo();
    await engine.enableAudioVolumeIndication(
      interval: 300,
      smooth: 3,
      reportVad: true,
    );
    _engine = engine;
    _handler = handler;
    _appId = appId;
  }

  @override
  Future<void> joinCall({
    required String token,
    required String channelId,
    required String userAccount,
    required bool withVideo,
  }) async {
    final engine = _requireEngine();
    await engine.registerLocalUserAccount(
      appId: _appId!,
      userAccount: userAccount,
    );
    await engine.enableLocalVideo(withVideo);
    if (withVideo) await engine.startPreview();
    await engine.joinChannelWithUserAccount(
      token: token,
      channelId: channelId,
      userAccount: userAccount,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
  }

  @override
  Future<void> joinScreenChannel({
    required String token,
    required String channelId,
    required String userAccount,
  }) async {
    final engine = _requireEngine();
    _screenChannelId = channelId;
    await engine.joinChannelWithUserAccountEx(
      token: token,
      channelId: channelId,
      userAccount: userAccount,
      // Joined to watch others' shares; publishes only while sharing.
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        publishScreenTrack: false,
        autoSubscribeAudio: false,
        autoSubscribeVideo: true,
      ),
    );
  }

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    await _requireEngine().muteLocalAudioStream(muted);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    final engine = _requireEngine();
    await engine.enableLocalVideo(enabled);
    await engine.muteLocalVideoStream(!enabled);
    if (enabled) {
      await engine.startPreview();
    } else {
      await engine.stopPreview();
    }
  }

  @override
  Future<List<BuzzScreenSource>> screenSources() async {
    final sources = await _requireEngine().getScreenCaptureSources(
      thumbSize: const SIZE(width: 320, height: 180),
      iconSize: const SIZE(width: 32, height: 32),
      includeScreen: true,
    );
    return [
      for (final source in sources)
        if (source.sourceId != null)
          BuzzScreenSource(
            id: source.sourceId!,
            name: (source.sourceTitle?.isNotEmpty ?? false)
                ? source.sourceTitle!
                : (source.sourceName ?? ''),
            isScreen:
                source.type ==
                ScreenCaptureSourceType.screencapturesourcetypeScreen,
            isPrimary: source.primaryMonitor ?? false,
            thumbnail: source.thumbImage?.buffer,
          ),
    ];
  }

  @override
  Future<void> startScreenShare(BuzzScreenSource source) async {
    final engine = _requireEngine();
    final connection = _screenConnection;
    if (connection == null) {
      throw StateError('The screen-share channel is not joined.');
    }
    const params = ScreenCaptureParameters(
      frameRate: 15,
      captureMouseCursor: true,
    );
    if (source.isScreen) {
      await engine.startScreenCaptureByDisplayId(
        displayId: source.id,
        regionRect: const Rectangle(),
        captureParams: params,
      );
    } else {
      await engine.startScreenCaptureByWindowId(
        windowId: source.id,
        regionRect: const Rectangle(),
        captureParams: params,
      );
    }
    await engine.updateChannelMediaOptionsEx(
      options: const ChannelMediaOptions(publishScreenTrack: true),
      connection: connection,
    );
    _sharing = true;
  }

  @override
  Future<void> stopScreenShare() async {
    final engine = _engine;
    if (engine == null || !_sharing) return;
    _sharing = false;
    final connection = _screenConnection;
    if (connection != null) {
      await engine.updateChannelMediaOptionsEx(
        options: const ChannelMediaOptions(publishScreenTrack: false),
        connection: connection,
      );
    }
    await engine.stopScreenCapture();
  }

  @override
  Widget? remoteScreenView(int remoteUid) {
    final engine = _engine;
    final connection = _screenConnection;
    if (engine == null || connection == null) return null;
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(
          uid: remoteUid,
          renderMode: RenderModeType.renderModeFit,
        ),
        connection: connection,
      ),
    );
  }

  @override
  Future<void> leave() async {
    final engine = _engine;
    if (engine == null) return;
    await stopScreenShare();
    final connection = _screenConnection;
    _screenConnection = null;
    _screenChannelId = null;
    if (connection != null) {
      await engine.leaveChannelEx(connection: connection);
    }
    await engine.leaveChannel();
    await engine.stopPreview();
  }

  @override
  Future<void> dispose() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await leave();
    } catch (error) {
      AppLogger.w('Leaving the Buzz channels failed', error: error);
    }
    final handler = _handler;
    if (handler != null) engine.unregisterEventHandler(handler);
    _engine = null;
    _handler = null;
    _appId = null;
    await engine.release();
  }

  /// Closes [events]; only for when the provider itself goes away.
  void closeEvents() {
    if (!_events.isClosed) unawaited(_events.close());
  }

  RtcEngineEx _requireEngine() {
    final engine = _engine;
    if (engine == null) {
      throw StateError('The call engine is not initialised.');
    }
    return engine;
  }

  BuzzChannel _channelOf(RtcConnection connection) =>
      connection.channelId != null && connection.channelId == _screenChannelId
      ? BuzzChannel.screen
      : BuzzChannel.call;

  void _emit(BuzzCallEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  RtcEngineEventHandler _buildHandler() {
    return RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        final channel = _channelOf(connection);
        if (channel == BuzzChannel.screen) _screenConnection = connection;
        _emit(BuzzJoined(channel));
      },
      onRejoinChannelSuccess: (connection, elapsed) {
        _emit(BuzzLinkChanged(_channelOf(connection), BuzzLinkState.connected));
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        _emit(BuzzRemoteJoined(_channelOf(connection), remoteUid));
      },
      onUserOffline: (connection, remoteUid, reason) {
        _emit(
          BuzzRemoteLeft(
            _channelOf(connection),
            remoteUid,
            dropped: reason == UserOfflineReasonType.userOfflineDropped,
          ),
        );
      },
      onUserInfoUpdated: (uid, info) {
        final account = info.userAccount;
        if (account != null && account.isNotEmpty) {
          _emit(BuzzRemoteIdentified(uid, account));
        }
      },
      onRemoteVideoStateChanged:
          (connection, remoteUid, state, reason, elapsed) {
            final bool? isOn = switch (state) {
              RemoteVideoState.remoteVideoStateStarting ||
              RemoteVideoState.remoteVideoStateDecoding => true,
              RemoteVideoState.remoteVideoStateStopped ||
              RemoteVideoState.remoteVideoStateFailed => false,
              RemoteVideoState.remoteVideoStateFrozen => null,
            };
            if (isOn != null) {
              _emit(
                BuzzRemoteVideoChanged(_channelOf(connection), remoteUid, isOn),
              );
            }
          },
      onConnectionStateChanged: (connection, state, reason) {
        final linkState = switch (state) {
          ConnectionStateType.connectionStateConnecting =>
            BuzzLinkState.connecting,
          ConnectionStateType.connectionStateConnected =>
            BuzzLinkState.connected,
          ConnectionStateType.connectionStateReconnecting =>
            BuzzLinkState.reconnecting,
          ConnectionStateType.connectionStateDisconnected =>
            BuzzLinkState.disconnected,
          ConnectionStateType.connectionStateFailed => BuzzLinkState.failed,
        };
        _emit(BuzzLinkChanged(_channelOf(connection), linkState));
      },
      onAudioVolumeIndication: (connection, speakers, speakerNumber, total) {
        if (_channelOf(connection) != BuzzChannel.call) return;
        AudioVolumeInfo? loudest;
        for (final speaker in speakers) {
          if ((speaker.volume ?? 0) < _speakingVolume) continue;
          if (loudest == null ||
              (speaker.volume ?? 0) > (loudest.volume ?? 0)) {
            loudest = speaker;
          }
        }
        _emit(BuzzActiveSpeaker(loudest?.uid));
      },
      onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
        if (remoteUid != 0 || _channelOf(connection) != BuzzChannel.call) {
          return;
        }
        _emit(BuzzQualityChanged(_quality(txQuality, rxQuality)));
      },
      onError: (err, msg) {
        _emit(BuzzEngineError(msg.isNotEmpty ? msg : err.name));
      },
    );
  }

  /// The worse of the upload and download quality.
  static BuzzNetworkQuality _quality(QualityType tx, QualityType rx) {
    BuzzNetworkQuality map(QualityType q) => switch (q) {
      QualityType.qualityExcellent => BuzzNetworkQuality.excellent,
      QualityType.qualityGood => BuzzNetworkQuality.good,
      QualityType.qualityPoor => BuzzNetworkQuality.poor,
      QualityType.qualityBad => BuzzNetworkQuality.bad,
      QualityType.qualityVbad => BuzzNetworkQuality.veryBad,
      QualityType.qualityDown => BuzzNetworkQuality.down,
      _ => BuzzNetworkQuality.unknown,
    };
    final a = map(tx), b = map(rx);
    return a.index >= b.index ? a : b;
  }
}
