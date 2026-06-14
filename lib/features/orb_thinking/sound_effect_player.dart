import 'package:audioplayers/audioplayers.dart';

/// Sound Effect Player for Orb Thinking System
/// Plays matching audio when avatars appear
class SoundEffectPlayer {
  static AudioPlayer? _player;
  static bool _isDisposed = false;

  /// Get or create the singleton AudioPlayer instance
  static AudioPlayer get _audioPlayer {
    if (_player == null || _isDisposed) {
      _player = AudioPlayer();
      _isDisposed = false;
    }
    return _player!;
  }

  static const _avatarSoundMap = <String, String>{
    // Avatar keyword fragment → sound file
    'angry': 'sounds/tiger-roar.mp3',
    'dreaming': 'sounds/dream-sound.mp3',
    'excited': 'sounds/wow.mp3',
    'laughing': 'sounds/crowd-cheer.mp3',
    'thinking': 'sounds/hmmm-sound.mp3',
    'yoga': 'sounds/dream-sound.mp3',
    'sneezing': 'sounds/pig-squeak.mp3',
    'exhausted': 'sounds/puppy-whimpering.mp3',
    'santa_avatar': 'sounds/congratulations-message-notification.mp3',
    'playing_chess': 'sounds/game_sounds/Tile Moving 02.mp3',
    'skateboarding': 'sounds/whoosh.mp3',
    'music': 'sounds/game_sounds/Good.mp3',
    'smiling': 'sounds/game_sounds/Good.mp3',
    'happy': 'sounds/game_sounds/Good.mp3',
    'silent': 'sounds/dream-sound.mp3',
  };

  /// Play sound effect for given avatar asset path
  static Future<void> playForAvatar(String assetPath) async {
    try {
      if (_isDisposed) return; // Don't play if disposed

      final player = _audioPlayer;

      // Find matching sound based on avatar path
      for (final entry in _avatarSoundMap.entries) {
        if (assetPath.contains(entry.key)) {
          await player.stop(); // Stop any current sound
          await player.play(AssetSource(entry.value), volume: 0.3);
          return;
        }
      }

      // Default soft transition sound if no specific match
      await player.stop();
      await player.play(AssetSource('sounds/dream-sound.mp3'), volume: 0.2);
    } catch (e) {
      // Silently handle audio errors to not break the UI
      print('Sound effect error: $e');
    }
  }

  /// Stop any currently playing sound
  static Future<void> stop() async {
    try {
      if (_isDisposed || _player == null) return;
      await _player!.stop();
    } catch (e) {
      print('Sound stop error: $e');
    }
  }

  /// Dispose the audio player and prevent resource leaks
  static Future<void> dispose() async {
    try {
      if (_player != null && !_isDisposed) {
        await _player!.stop();
        await _player!.dispose();
        _isDisposed = true;
        _player = null;
      }
    } catch (e) {
      print('Sound dispose error: $e');
    }
  }
}
