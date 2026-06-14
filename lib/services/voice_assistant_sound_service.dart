import 'dart:async';
import 'package:just_audio/just_audio.dart';

import '../controllers/voice_assistant_game_controller.dart';

class VoiceAssistantSoundService {
  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  final AudioPlayer _oneshotPlayer = AudioPlayer();

  double _ambientVolume = 0.15;
  Timer? _silenceWatchdog;
  DateTime? _lastMicroConfirmation;

  final String _ambientBasePath = 'sounds/game_sounds/nature/';
  final String _effectsBasePath = 'sounds/game_sounds/';

  Future<void> startAmbient(String file, {double volume = 0.15}) async {
    try {
      _ambientVolume = volume;
      final path = '$_ambientBasePath$file';
      await _ambientPlayer.setAsset(path);
      await _ambientPlayer.setLoopMode(LoopMode.one);
      await _ambientPlayer.setVolume(volume);
      await _ambientPlayer.play();
    } catch (e) {
      print('VoiceAssistantSoundService: Error starting ambient: $e');
    }
  }

  Future<void> stopAmbient({bool fade = true}) async {
    if (fade) {
      await _fadeOutAmbient();
    } else {
      await _ambientPlayer.stop();
    }
  }

  Future<void> _fadeOutAmbient() async {
    final startVolume = _ambientPlayer.volume;
    const steps = 10;
    const stepDelay = Duration(milliseconds: 100);
    for (int i = steps; i >= 0; i--) {
      await _ambientPlayer.setVolume(startVolume * (i / steps));
      await Future.delayed(stepDelay);
    }
    await _ambientPlayer.stop();
  }

  Future<void> crossFadeAmbient(String newFile) async {
    final oldPlayer = _ambientPlayer;
    final newPlayer = AudioPlayer();
    try {
      final path = '$_ambientBasePath$newFile';
      await newPlayer.setAsset(path);
      await newPlayer.setLoopMode(LoopMode.one);
      await newPlayer.setVolume(0.01);
      await newPlayer.play();

      for (int i = 0; i <= 10; i++) {
        await oldPlayer.setVolume(_ambientVolume * (1 - i / 10));
        await newPlayer.setVolume(_ambientVolume * (i / 10));
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await oldPlayer.stop();
    } catch (e) {
      print('VoiceAssistantSoundService: Error crossfading ambient: $e');
      await newPlayer.dispose();
    }
  }

  Future<void> play(String file, {double volume = 1.0}) async {
    try {
      await _oneshotPlayer.setAsset('$_effectsBasePath$file');
      await _oneshotPlayer.setVolume(volume);
      await _oneshotPlayer.play();
    } catch (e) {
      print('VoiceAssistantSoundService: Error playing effect: $e');
    }
  }

  Future<void> duckAmbient() async {
    const steps = 6;
    const stepDelay = Duration(milliseconds: 50);
    for (int i = 0; i <= steps; i++) {
      await _ambientPlayer.setVolume(_ambientVolume * (1 - (0.1 * i / steps)));
      await Future.delayed(stepDelay);
    }
  }

  Future<void> restoreAmbient() async {
    const steps = 10;
    const stepDelay = Duration(milliseconds: 50);
    final currentVolume = _ambientPlayer.volume;
    for (int i = 0; i <= steps; i++) {
      await _ambientPlayer.setVolume(
          currentVolume + (_ambientVolume - currentVolume) * (i / steps));
      await Future.delayed(stepDelay);
    }
  }

  Future<void> playMicroConfirmation() async {
    final now = DateTime.now();
    if (_lastMicroConfirmation != null &&
        now.difference(_lastMicroConfirmation!).inSeconds < 2) {
      return;
    }
    _lastMicroConfirmation = now;
    await play('button1.mp3', volume: 0.6);
  }

  void startSilenceWatchdog({Duration timeout = const Duration(seconds: 45)}) {
    cancelSilenceWatchdog();
    _silenceWatchdog = Timer(timeout, () {
      play('bird-sound.mp3', volume: 0.4);
    });
  }

  void resetSilenceWatchdog() {
    _silenceWatchdog?.cancel();
    _silenceWatchdog = null;
  }

  void cancelSilenceWatchdog() {
    _silenceWatchdog?.cancel();
    _silenceWatchdog = null;
  }

  Future<void> playStateTransition(OrbState from, OrbState to) async {
    switch (from) {
      case OrbState.idle:
        if (to == OrbState.listening) {
          await crossFadeAmbient('Rain Leaves.mp3');
        }
        break;
      case OrbState.listening:
        if (to == OrbState.processing) {
          await play('click_enter.mp3', volume: 0.8);
          await crossFadeAmbient('Rain Leaves.mp3');
        }
        break;
      case OrbState.processing:
        if (to == OrbState.speaking) {
          await stopAmbient(fade: true);
          await play('level_change_2.mp3', volume: 0.7);
        }
        break;
      case OrbState.speaking:
        if (to == OrbState.listening) {
          await startAmbient('Coastal.mp3', volume: 0.15);
          await play('UI Menu Mouseover 02.mp3', volume: 0.5);
        }
        break;
      default:
        break;
    }
  }

  Future<void> playFarewellSequence() async {
    await play('whoosh.mp3', volume: 0.8);
    await Future.delayed(const Duration(milliseconds: 800));
    await play('Goodbye.mp3', volume: 0.9);
    await Future.delayed(const Duration(milliseconds: 1500));
    await play('Firework Explosion 05.mp3', volume: 0.7);
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  void dispose() {
    cancelSilenceWatchdog();
    _ambientPlayer.dispose();
    _effectPlayer.dispose();
    _oneshotPlayer.dispose();
  }
}
