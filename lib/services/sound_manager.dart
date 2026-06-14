import 'dart:math';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

/// Game-event → sound-file map. Centralized so the controller can ask
/// for "the rating sound" without knowing which mp3 file backs it.
enum GameSound {
  buttonClick,
  ballMove,
  liquidPour,
  getReady,
  levelComplete,
  ratingIncredible,
  ratingExcellent,
  ratingGood,
  wrongMove,
  timeLow,
  timeExpiring,
  hint,
  gameOver,
  noMoreMoves,
  finalCelebration,
  idleRooster,
  undoReverse,
}

class GameSoundMap {
  static const Map<GameSound, String> files = {
    GameSound.buttonClick: 'bell-ring.mp3',
    GameSound.ballMove: 'whoosh.mp3',
    GameSound.liquidPour: 'whoosh.mp3',
    GameSound.getReady: 'setting-statement.mp3',
    GameSound.levelComplete: 'congratulations-message-notification.mp3',
    GameSound.ratingIncredible: 'crowd-cheer.mp3',
    GameSound.ratingExcellent: 'wow.mp3',
    GameSound.ratingGood: 'right-ans.mp3',
    GameSound.wrongMove: 'wrong-ans.mp3',
    GameSound.timeLow: 'heart-beat-10sec-timer.mp3',
    GameSound.timeExpiring: 'heart-beat-10sec-timer.mp3',
    GameSound.hint: 'bell-ring.mp3',
    GameSound.gameOver: 'wrong-ans.mp3',
    GameSound.noMoreMoves: 'wrong-ans.mp3',
    GameSound.finalCelebration: 'air-horn.mp3',
    GameSound.idleRooster: 'rooster-cry.mp3',
    GameSound.undoReverse: 'going-in-reverse.mp3',
  };
}

class SoundManager extends GetxService {
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _fxPlayer = AudioPlayer();

  final List<String> _bgTracks = ['chinese_map.mp3', 'fairy_tale_level.mp3'];

  Future<void> startBackgroundMusic() async {
    final track = _bgTracks[Random().nextInt(_bgTracks.length)];
    try {
      await _bgPlayer.setAsset('assets/sounds/$track');
      _bgPlayer.setLoopMode(LoopMode.one);
      _bgPlayer.setVolume(0.6);
      _bgPlayer.play();
    } catch (_) {}
  }

  Future<void> playFX(String filename, {bool duck = false}) async {
    try {
      if (duck) await _bgPlayer.setVolume(0.15);
      await _fxPlayer.setAsset('assets/sounds/$filename');
      await _fxPlayer.play();
      if (duck) {
        await Future.delayed(_fxPlayer.duration ?? const Duration(seconds: 2));
        await _bgPlayer.setVolume(0.6);
      }
    } catch (_) {}
  }

  /// Plays a game-event sound. Falls through silently if the asset is
  /// missing so a bad mapping never crashes gameplay.
  Future<void> playGameSound(GameSound sound, {bool duck = false}) {
    final file = GameSoundMap.files[sound];
    if (file == null) return Future.value();
    return playFX(file, duck: duck);
  }

  void stopAll() {
    _bgPlayer.stop();
    _fxPlayer.stop();
  }

  @override
  void onClose() {
    _bgPlayer.dispose();
    _fxPlayer.dispose();
    super.onClose();
  }
}
