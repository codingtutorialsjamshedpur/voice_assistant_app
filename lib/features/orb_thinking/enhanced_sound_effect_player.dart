import 'package:audioplayers/audioplayers.dart';

/// Enhanced Sound Effect Player for Orb Thinking System
/// Plays synchronized audio for orb blinking, cloud effects, and avatar transitions
class EnhancedSoundEffectPlayer {
  static AudioPlayer? _player;
  static bool _isDisposed = false;
  static String? _lastPlayedAvatar;

  static AudioPlayer get _audioPlayer {
    if (_player == null || _isDisposed) {
      _player = AudioPlayer();
      _isDisposed = false;
    }
    return _player!;
  }

  /// Step 1: Orb is thinking
  static Future<void> playOrbBlinking() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/hmmm-sound.mp3'),
          volume: 0.35);
    } catch (_) {}
  }

  /// Step 2: Cloud appears
  static Future<void> playCloudAppearance() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource('sounds/game_sounds/Pixelus Hint Screen v01.mp3'),
        volume: 0.25,
      );
    } catch (_) {}
  }

  /// Step 3: Avatar-specific sound — interrupts any current audio
  static Future<void> playForAvatar(String assetPath) async {
    if (assetPath == _lastPlayedAvatar) return; // No repeat for same avatar
    _lastPlayedAvatar = assetPath;
    try {
      final sound = _resolveAvatarSound(assetPath);
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(sound), volume: 0.3);
    } catch (_) {}
  }

  static void resetLastAvatar() => _lastPlayedAvatar = null;

  static String _resolveAvatarSound(String path) {
    if (path.contains('angry')) return 'sounds/tiger-roar.mp3';
    if (path.contains('dreaming')) return 'sounds/dream-sound.mp3';
    if (path.contains('excited')) return 'sounds/wow.mp3';
    if (path.contains('laughing')) return 'sounds/crowd-cheer.mp3';
    if (path.contains('thinking')) return 'sounds/hmmm-sound.mp3';
    if (path.contains('yoga')) return 'sounds/game_sounds/nature/Forest.mp3';
    if (path.contains('music')) return 'sounds/game_sounds/Good.mp3';
    if (path.contains('happy') || path.contains('smiling')) {
      return 'sounds/game_sounds/Good.mp3';
    }
    if (path.contains('exhausted')) return 'sounds/puppy-whimpering.mp3';
    if (path.contains('cowboy')) return 'sounds/horse-snort.mp3';
    if (path.contains('ghost')) return 'sounds/scary-sound.mp3';
    if (path.contains('exercising')) return 'sounds/Go.mp3';
    if (path.contains('santa')) {
      return 'sounds/congratulations-message-notification.mp3';
    }
    if (path.contains('nervous')) return 'sounds/heart-beat-10sec-timer.mp3';
    return 'sounds/dream-sound.mp3'; // Default — soft, neutral
  }

  static Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  static Future<void> dispose() async {
    try {
      if (_player != null && !_isDisposed) {
        await _player!.stop();
        await _player!.dispose();
        _isDisposed = true;
        _player = null;
        _lastPlayedAvatar = null;
      }
    } catch (_) {}
  }
}
