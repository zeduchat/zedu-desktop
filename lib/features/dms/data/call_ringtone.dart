import 'package:audioplayers/audioplayers.dart'
    show AssetSource, AudioPlayer, ReleaseMode;
import 'package:zedu/core/core.dart';

/// Plays the ringtone while a call is coming in.
abstract class CallRingtone {
  /// Starts the looping ringtone. Does nothing if it is already playing.
  Future<void> start();

  /// Stops the ringtone. Does nothing if it is not playing.
  Future<void> stop();

  /// Releases the player.
  Future<void> dispose();
}

final callRingtoneProvider = Provider<CallRingtone>((ref) {
  final ringtone = AudioCallRingtone();
  ref.onDispose(ringtone.dispose);
  return ringtone;
});

/// [CallRingtone] backed by audioplayers, looping a bundled chime.
class AudioCallRingtone implements CallRingtone {
  /// Relative to the assets folder, as audioplayers expects.
  static const asset = 'sounds/incoming_call.wav';

  AudioPlayer? _player;
  bool _playing = false;

  @override
  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    try {
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource(asset));
    } catch (error) {
      // A missing audio device must never break the call itself.
      _playing = false;
      AppLogger.w('Could not play the incoming call ringtone', error: error);
    }
  }

  @override
  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player?.stop();
    } catch (error) {
      AppLogger.w('Could not stop the incoming call ringtone', error: error);
    }
  }

  @override
  Future<void> dispose() async {
    _playing = false;
    final player = _player;
    _player = null;
    try {
      await player?.dispose();
    } catch (_) {}
  }
}
