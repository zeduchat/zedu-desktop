import 'package:audioplayers/audioplayers.dart'
    show AssetSource, AudioPlayer, ReleaseMode;
import 'package:zedu/core/core.dart';

/// Plays the short sound that goes with a message notification.
abstract class MessageSound {
  /// Plays the sound from the start. A sound still playing is restarted.
  Future<void> play();

  /// Releases the player.
  Future<void> dispose();
}

final messageSoundProvider = Provider<MessageSound>((ref) {
  final sound = AudioMessageSound();
  ref.onDispose(sound.dispose);
  return sound;
});

/// [MessageSound] backed by audioplayers, playing a short bundled chime.
class AudioMessageSound implements MessageSound {
  /// Relative to the assets folder, as audioplayers expects.
  static const asset = 'sounds/message.wav';

  AudioPlayer? _player;

  @override
  Future<void> play() async {
    try {
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource(asset));
    } catch (error) {
      // A missing audio device must never get in the way of the notification.
      AppLogger.w('Could not play the message sound', error: error);
    }
  }

  @override
  Future<void> dispose() async {
    final player = _player;
    _player = null;
    try {
      await player?.dispose();
    } catch (_) {}
  }
}
