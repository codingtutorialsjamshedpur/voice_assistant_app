import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class SoundService extends GetxService {
  static SoundService get to => Get.find();

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  final AudioPlayer _gesturePlayer = AudioPlayer();

  // Alarm effects timers
  Timer? _alarmVolumeTimer;
  Timer? _vibrationTimer;

  // Volume settings
  final RxDouble masterVolume = 1.0.obs;
  final RxDouble musicVolume = 0.7.obs;
  final RxDouble effectsVolume = 1.0.obs;
  final RxDouble gestureVolume = 0.8.obs;

  // ========== CORE APP SOUNDS ==========
  static const String splashSound =
      'sounds/game_sounds/app_splashscreen_sound.mp3';
  static const String clickSound = 'sounds/game_sounds/click_enter.mp3';
  static const String welcomeSound = 'sounds/game_sounds/Welcome_Back.mp3';
  static const String transitionSound = 'sounds/game_sounds/level_change_1.mp3';
  static const String transitionAltSound =
      'sounds/game_sounds/level_change_2.mp3';

  // ========== SUCCESS & ACHIEVEMENT SOUNDS ==========
  static const String successSound = 'sounds/game_sounds/Level_Complete.mp3';
  static const String excellentSound = 'sounds/game_sounds/excellent1.mp3';
  static const String incredibleSound = 'sounds/game_sounds/Incredible.mp3';
  static const String worldComplete = 'sounds/game_sounds/World_Complete.mp3';
  static const String puzzleSolved = 'sounds/game_sounds/Puzzle_Solved.mp3';
  static const String newHighScore = 'sounds/game_sounds/A_New_High_Score.mp3';
  static const String goodSound = 'sounds/game_sounds/Good.mp3';
  static const String crowdApplause =
      'sounds/game_sounds/Crowd Applause 01.mp3';
  static const String crowdCheer = 'sounds/crowd-cheer.mp3';

  // ========== GAME & ACTIVITY SOUNDS ==========
  static const String goSound = 'sounds/game_sounds/Go.mp3';
  static const String getReadySound = 'sounds/game_sounds/Get_ready.mp3';
  static const String timeUp = 'sounds/game_sounds/Time_Up.mp3';
  static const String noMoreMoves = 'sounds/game_sounds/No_More_Moves.mp3';
  static const String gameOver = 'sounds/game_sounds/Game_Over.mp3';

  // ========== GESTURE & INTERACTION SOUNDS ==========
  static const String whoosh = 'sounds/whoosh.mp3';
  static const String wow = 'sounds/wow.mp3';
  static const String notification =
      'sounds/congratulations-message-notification.mp3';
  static const String rightAnswer = 'sounds/right-ans.mp3';
  static const String wrongAnswer = 'sounds/wrong-ans.mp3';
  static const String bellRing = 'sounds/bell-ring.mp3';
  static const String airHorn = 'sounds/air-horn.mp3';
  static const String heartbeat = 'sounds/heart-beat-10sec-timer.mp3';

  // ========== SPIRITUAL & AMBIENT SOUNDS ==========
  static const String goodbye = 'sounds/game_sounds/Goodbye.mp3';
  static const String dreamSound = 'sounds/dream-sound.mp3';
  static const String hmmmSound = 'sounds/hmmm-sound.mp3';
  static const String rainThunder = 'sounds/rain-and-thunder-32sec.mp3';
  static const String settingStatement = 'sounds/setting-statement.mp3';

  // ========== ANIMAL SOUNDS (For fun interactions) ==========
  static const String birdChirp = 'sounds/bird-sound.mp3';
  static const String owlHoot = 'sounds/owl-hoot.mp3';
  static const String wolfHowl = 'sounds/wolf-howl.mp3';

  // ========== INDIAN STYLE SOUNDS ==========
  static const String aahistaSong = 'sounds/Yun_Aahista_Aahista.mp3';

  Future<SoundService> init() async {
    await _player.setVolume(musicVolume.value);
    await _effectPlayer.setVolume(effectsVolume.value);
    await _gesturePlayer.setVolume(gestureVolume.value);
    return this;
  }

  // ========== CORE APP SOUND METHODS ==========

  /// Play splash sound (exactly 6 seconds)
  Future<void> playSplashSound() async {
    try {
      final String fullPath = splashSound.startsWith('assets/')
          ? splashSound
          : 'assets/$splashSound';
      await _player.setAsset(fullPath);
      await _player.setLoopMode(LoopMode.off);
      await _player.play();
    } catch (e) {
      print('Error playing splash sound: $e');
    }
  }

  /// Play effect sound (short sounds)
  Future<void> playEffect(String soundPath) async {
    try {
      final String fullPath =
          soundPath.startsWith('assets/') ? soundPath : 'assets/$soundPath';
      await _effectPlayer.setAsset(fullPath);
      await _effectPlayer.play();
    } catch (e) {
      print('Error playing effect: $e');
    }
  }

  /// Play gesture sound (subtle UI sounds)
  Future<void> playGestureSound(String soundPath) async {
    try {
      final String fullPath =
          soundPath.startsWith('assets/') ? soundPath : 'assets/$soundPath';
      await _gesturePlayer.setAsset(fullPath);
      await _gesturePlayer.setVolume(gestureVolume.value * 0.5);
      await _gesturePlayer.play();
    } catch (e) {
      print('Error playing gesture sound: $e');
    }
  }

  // ========== BUTTON & CLICK SOUNDS ==========

  Future<void> playClick() async {
    await playEffect(clickSound);
    lightHaptic();
  }

  Future<void> playButtonPress() async {
    await playEffect(clickSound);
    selectionHaptic();
  }

  Future<void> playToggle() async {
    await playEffect('sounds/game_sounds/click_enter.mp3');
    lightHaptic();
  }

  // ========== NAVIGATION SOUNDS ==========

  Future<void> playTransition() async {
    await playEffect(transitionSound);
  }

  Future<void> playPageTransition() async {
    await playEffect(transitionAltSound);
    lightHaptic();
  }

  Future<void> playScreenOpen() async {
    await playEffect(whoosh);
    lightHaptic();
  }

  Future<void> playScreenClose() async {
    await playEffect(whoosh);
  }

  // ========== SUCCESS & FEEDBACK SOUNDS ==========

  Future<void> playSuccess() async {
    // Level_Complete.mp3 removed from playSuccess() to stop loud noise on basic app interactions
    mediumHaptic();
  }

  Future<void> playExcellent() async {
    await playEffect(excellentSound);
    mediumHaptic();
  }

  Future<void> playIncredible() async {
    await playEffect(incredibleSound);
    heavyHaptic();
  }

  Future<void> playAchievement() async {
    await playEffect(worldComplete);
    await playEffect(crowdApplause);
    heavyHaptic();
  }

  Future<void> playCompletion() async {
    await playEffect(puzzleSolved);
    mediumHaptic();
  }

  Future<void> playGoodJob() async {
    await playEffect(goodSound);
    lightHaptic();
  }

  Future<void> playWelcome() async {
    await playEffect(welcomeSound);
    lightHaptic();
  }

  Future<void> playCheer() async {
    await playEffect(crowdCheer);
    heavyHaptic();
  }

  // ========== GAME & ACTIVITY SOUNDS ==========

  Future<void> playGo() async {
    await playEffect(goSound);
    mediumHaptic();
  }

  Future<void> playGetReady() async {
    await playEffect(getReadySound);
    lightHaptic();
  }

  Future<void> playTimeUp() async {
    await playEffect(timeUp);
    mediumHaptic();
  }

  Future<void> playGameOver() async {
    await playEffect(gameOver);
  }

  Future<void> playNoMoreMoves() async {
    await playEffect(noMoreMoves);
    lightHaptic();
  }

  // ========== GESTURE & INTERACTION SOUNDS ==========

  Future<void> playWhoosh() async {
    await playGestureSound(whoosh);
  }

  Future<void> playSwipe() async {
    await playGestureSound(whoosh);
    lightHaptic();
  }

  Future<void> playScroll() async {
    await playGestureSound(whoosh);
  }

  Future<void> playNotification() async {
    await playEffect(notification);
    lightHaptic();
  }

  Future<void> playWow() async {
    await playEffect(wow);
    mediumHaptic();
  }

  Future<void> playCorrect() async {
    await playEffect(rightAnswer);
    mediumHaptic();
  }

  Future<void> playWrong() async {
    await playEffect(wrongAnswer);
    lightHaptic();
  }

  Future<void> playAlarm() async {
    await playEffect(bellRing);
  }

  /// Play alarm with specific sound - supports both predefined sounds and custom paths
  Future<void> playAlarmWithSound(String soundName,
      {String? customVoicePath}) async {
    try {
      _alarmVolumeTimer?.cancel();
      _vibrationTimer?.cancel();

      // Ensure immediate full volume for alarm
      await _player.setVolume(1.0);

      if (customVoicePath != null) {
        // Play custom voice recording
        await _player.setFilePath(customVoicePath);
        await _player.setLoopMode(LoopMode.all);
        await _player.play();
      } else {
        // Map sound name to asset path
        final soundPath = _getAlarmSoundPath(soundName);
        final fullPath =
            soundPath.startsWith('assets/') ? soundPath : 'assets/$soundPath';
        await _player.setAsset(fullPath);
        await _player.setLoopMode(LoopMode.all);
        await _player.play();
      }

      // Pattern-based vibration (AL-05)
      _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        heavyHaptic();
        Future.delayed(const Duration(milliseconds: 300), () => heavyHaptic());
      });
    } catch (e) {
      print('Error playing alarm sound: $e');
      // Fallback to default bell ring
      await playAlarm();
    }
  }

  String _getAlarmSoundPath(String soundName) {
    switch (soundName) {
      case 'Bell Ring':
        return bellRing;
      case 'Bird Chirping':
        return birdChirp;
      case 'Air Horn':
        return airHorn;
      case 'Dream Sound':
        return dreamSound;
      default:
        return bellRing;
    }
  }

  Future<void> playAlert() async {
    await playEffect(airHorn);
    heavyHaptic();
  }

  Future<void> playHeartbeat() async {
    await playEffect(heartbeat);
  }

  // ========== SPIRITUAL & AMBIENT SOUNDS ==========

  Future<void> playGoodbye() async {
    await playEffect(goodbye);
    lightHaptic();
  }

  Future<void> playBell() async {
    await playEffect(bellRing);
    lightHaptic();
  }

  Future<void> playDreamy() async {
    await playEffect(dreamSound);
  }

  Future<void> playThinking() async {
    await playEffect(hmmmSound);
  }

  Future<void> playSettingOpen() async {
    await playEffect(settingStatement);
    lightHaptic();
  }

  // ========== ANIMAL SOUNDS (For fun interactions) ==========

  Future<void> playBirdChirp() async {
    await playEffect(birdChirp);
  }

  Future<void> playOwlHoot() async {
    await playEffect(owlHoot);
  }

  Future<void> playWolfHowl() async {
    await playEffect(wolfHowl);
  }

  // ========== INDIAN STYLE SOUNDS ==========

  Future<void> playAahistaSong() async {
    final String fullPath =
        aahistaSong.startsWith('assets/') ? aahistaSong : 'assets/$aahistaSong';
    await _player.setAsset(fullPath);
    await _player.play();
  }

  // ========== UTILITY METHODS ==========

  Future<void> stopAll() async {
    _alarmVolumeTimer?.cancel();
    _vibrationTimer?.cancel();
    // Reset volume to normal default when stopping
    await _player.setVolume(musicVolume.value);

    await _player.stop();
    await _effectPlayer.stop();
    await _gesturePlayer.stop();
  }

  Future<void> pauseAll() async {
    await _player.pause();
    await _effectPlayer.pause();
    await _gesturePlayer.pause();
  }

  Future<void> resumeAll() async {
    await _player.play();
    await _effectPlayer.play();
    await _gesturePlayer.play();
  }

  // ========== HAPTIC FEEDBACK ==========

  void lightHaptic() {
    HapticFeedback.lightImpact();
  }

  void mediumHaptic() {
    HapticFeedback.mediumImpact();
  }

  void heavyHaptic() {
    HapticFeedback.heavyImpact();
  }

  void selectionHaptic() {
    HapticFeedback.selectionClick();
  }

  void vibrate() {
    HapticFeedback.vibrate();
  }

  @override
  void onClose() {
    _player.dispose();
    _effectPlayer.dispose();
    _gesturePlayer.dispose();
    super.onClose();
  }
}
