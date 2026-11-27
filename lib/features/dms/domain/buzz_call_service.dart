import 'package:zedu/core/core.dart';

/// Which of a call's two Agora channels an event belongs to: the call itself
/// (`buzz_id`) or its screen-share channel (`screen-<buzz_id>`).
enum BuzzChannel { call, screen }

/// The state of the link to Agora for one channel.
enum BuzzLinkState { connecting, connected, reconnecting, disconnected, failed }

/// How good the local network is, from Agora's quality reports.
enum BuzzNetworkQuality { unknown, excellent, good, poor, bad, veryBad, down }

/// Something that happened in the media engine during a call.
sealed class BuzzCallEvent {
  const BuzzCallEvent();
}

/// This app joined [channel].
class BuzzJoined extends BuzzCallEvent {
  const BuzzJoined(this.channel);
  final BuzzChannel channel;
}

/// Someone else joined [channel] as [remoteUid] (Agora's numeric id).
class BuzzRemoteJoined extends BuzzCallEvent {
  const BuzzRemoteJoined(this.channel, this.remoteUid);
  final BuzzChannel channel;
  final int remoteUid;
}

/// Someone left [channel]. [dropped] is true when Agora lost them rather than
/// them leaving on purpose.
class BuzzRemoteLeft extends BuzzCallEvent {
  const BuzzRemoteLeft(this.channel, this.remoteUid, {this.dropped = false});
  final BuzzChannel channel;
  final int remoteUid;
  final bool dropped;
}

/// Agora resolved a numeric uid to the user account (user id) it joined with.
class BuzzRemoteIdentified extends BuzzCallEvent {
  const BuzzRemoteIdentified(this.remoteUid, this.userAccount);
  final int remoteUid;
  final String userAccount;
}

/// A remote video stream in [channel] started or stopped. On the screen
/// channel this is how a remote screen share shows up.
class BuzzRemoteVideoChanged extends BuzzCallEvent {
  const BuzzRemoteVideoChanged(this.channel, this.remoteUid, this.isOn);
  final BuzzChannel channel;
  final int remoteUid;
  final bool isOn;
}

/// The link for [channel] changed state.
class BuzzLinkChanged extends BuzzCallEvent {
  const BuzzLinkChanged(this.channel, this.state);
  final BuzzChannel channel;
  final BuzzLinkState state;
}

/// The loudest speaker right now: 0 is this app's user, otherwise a remote
/// uid. Null when nobody is speaking.
class BuzzActiveSpeaker extends BuzzCallEvent {
  const BuzzActiveSpeaker(this.uid);
  final int? uid;
}

/// The local network quality changed.
class BuzzQualityChanged extends BuzzCallEvent {
  const BuzzQualityChanged(this.quality);
  final BuzzNetworkQuality quality;
}

/// The engine reported an error it can't recover from by itself.
class BuzzEngineError extends BuzzCallEvent {
  const BuzzEngineError(this.message);
  final String message;
}

/// A screen or window that can be shared.
class BuzzScreenSource {
  const BuzzScreenSource({
    required this.id,
    required this.name,
    required this.isScreen,
    this.isPrimary = false,
    this.thumbnail,
  });

  final int id;
  final String name;
  final bool isScreen;
  final bool isPrimary;

  /// The preview image bytes exactly as the SDK returns them, when the
  /// platform provides one. The picker decodes them.
  final Uint8List? thumbnail;
}

/// The media side of a call: Agora behind an interface so tests can fake it.
///
/// A call uses two Agora channels. [joinCall] joins the call's own channel as
/// the user; [joinScreenChannel] joins `screen-<buzz_id>` as
/// `screen-<user id>`, which is how shares are published and watched.
abstract class BuzzCallService {
  /// False on platforms the media SDK doesn't support (Linux).
  bool get isSupported;

  Stream<BuzzCallEvent> get events;

  /// Creates the engine with the App ID the backend returned. Safe to call
  /// again with the same App ID.
  Future<void> initialize(String appId);

  Future<void> joinCall({
    required String token,
    required String channelId,
    required String userAccount,
    required bool withVideo,
  });

  Future<void> joinScreenChannel({
    required String token,
    required String channelId,
    required String userAccount,
  });

  Future<void> setMicrophoneMuted(bool muted);

  Future<void> setCameraEnabled(bool enabled);

  Future<List<BuzzScreenSource>> screenSources();

  /// Captures [source] and publishes it on the screen channel.
  Future<void> startScreenShare(BuzzScreenSource source);

  Future<void> stopScreenShare();

  /// Renders the share [remoteUid] publishes on the screen channel, or null
  /// while the screen channel isn't joined.
  Widget? remoteScreenView(int remoteUid);

  /// Leaves both channels. The engine stays ready for another call.
  Future<void> leave();

  /// Leaves and releases the engine.
  Future<void> dispose();
}
