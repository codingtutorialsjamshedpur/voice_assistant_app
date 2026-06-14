import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import '../../../controllers/ball_sort_controller.dart';
import '../../../controllers/language_controller.dart';
import '../../../routes/app_routes.dart';
import '../../../services/translation_service.dart';
import '../../../services/level_generator_service.dart';
import '../../../services/puzzle_solver_service.dart';
import '../../../services/score_manager.dart';
import '../../../services/sound_manager.dart';
import '../../../services/animation_manager.dart';
import 'voice_game.dart';

class BallSortPuzzleGame extends VoiceGame {
  BallSortPuzzleGame(super.controller);

  late BallSortController _bsc;

  @override
  Future<void> onStart() async {
    applySttLocale();
    Get.put(SoundManager());
    Get.put(PuzzleSolverService());
    Get.put(LevelGeneratorService());
    Get.put(ScoreManager());
    Get.put(AnimationManager());
    _bsc = Get.put(BallSortController());

    _bsc.onIdleTimeout = () => onIdleTimeout();
    _bsc.onMoveCompleted = () => _onMoveCompleted();

    playSound('assets/sounds/game_sounds/Pixelus Start of Puzzle v02.mp3');
    await Future.delayed(const Duration(milliseconds: 800));
    playSound('assets/sounds/game_sounds/Get_ready.mp3');

    _bsc.startLevel(_bsc.loadSavedLevel());

    final greeting = await _t('Welcome to Ball Sort Puzzle! '
        'Tap a tube to select it, then tap another to pour the ball. '
        'You can also say: "Move tube 1 to tube 3", or "hint", "undo", "restart". '
        'Level 1 — let\'s begin!');
    addMessage(greeting);
    speak(greeting);
  }

  @override
  Future<void> onInput(String rawText) async {
    final intent = await _parseIntent(rawText);

    switch (intent['action']) {
      case 'BALL_MOVE':
        await _handleMove(intent['src'] as int, intent['dst'] as int);
        break;
      case 'UNDO':
        _handleUndo();
        break;
      case 'REDO':
        _handleRedo();
        break;
      case 'HINT':
        await _handleHint();
        break;
      case 'RESTART':
        _handleRestart();
        break;
      case 'NEXT':
        if (_bsc.isLevelComplete.value) _handleNextLevel();
        break;
      case 'EXIT':
        await _handleExit();
        break;
      default:
        await _handleUnknown(rawText);
    }
  }

  @override
  void onDispose() {
    _bsc.dispose();
    Get.delete<BallSortController>();
  }

  void _onMoveCompleted() {
    if (_bsc.isLevelComplete.value) {
      _celebrateLevel();
    } else {
      final hint = _bsc.getSilentHint();
      if (hint != null) {
        _t('Next, move Tube ${hint[0] + 1} to Tube ${hint[1] + 1}.')
            .then((msg) {
          addMessage(msg);
          speak(msg);
        });
      } else {
        if (_bsc.moveCount.value % 4 == 0) {
          _smartComment().then((comment) {
            addMessage(comment);
            speak(comment);
          });
        }
      }
    }
  }

  Future<void> _handleMove(int src, int dst) async {
    final srcIdx = src - 1;
    final dstIdx = dst - 1;

    if (srcIdx < 0 ||
        dstIdx < 0 ||
        srcIdx >= _bsc.tubes.length ||
        dstIdx >= _bsc.tubes.length) {
      playSound('assets/sounds/game_sounds/warning1.mp3');
      final msg = await _t('Tube number out of range. Try again.');
      addMessage(msg);
      speak(msg);
      return;
    }

    final success = _bsc.tryMove(srcIdx, dstIdx);

    if (success) {
      playSound('assets/sounds/game_sounds/Tile Moving 02.mp3');
    } else {
      playSound('assets/sounds/game_sounds/warning1.mp3');
      final msg = await _t('That move is not allowed. Try a different tube.');
      addMessage(msg);
      speak(msg);
    }
  }

  void _handleUndo() {
    _bsc.undo();
    playSound('assets/sounds/game_sounds/reverse1.mp3');
  }

  void _handleRedo() {
    _bsc.redo();
    playSound('assets/sounds/game_sounds/click_enter.mp3');
  }

  Future<void> _handleHint() async {
    final hint = _bsc.computeHint();
    _bsc.hintsUsed.value++;
    playSound('assets/sounds/game_sounds/Pixelus Hint Screen v01.mp3');

    if (hint != null) {
      _bsc.hintHighlight.assignAll(hint);
      final msg =
          await _t('Try moving Tube ${hint[0] + 1} into Tube ${hint[1] + 1}.');
      addMessage(msg);
      speak(msg);

      Future.delayed(const Duration(milliseconds: 2500), () {
        _bsc.hintHighlight.clear();
      });
    } else {
      final msg = await _t('No hint available right now. Keep trying!');
      addMessage(msg);
      speak(msg);
    }
  }

  void _handleRestart() {
    playSound('assets/sounds/game_sounds/button1.mp3');
    _bsc.restartLevel();
  }

  void _handleNextLevel() {
    playSound('assets/sounds/game_sounds/level_change_1.mp3');
    _bsc.loadNextLevel();
  }

  Future<void> _handleExit() async {
    playSound('assets/sounds/game_sounds/Goodbye.mp3');
    final msg = await _t('Returning to Game Hub. Great playing!');
    addMessage(msg);
    speak(msg);
    await Future.delayed(const Duration(seconds: 1));
    controller.resetToHub();
    Get.offNamed(AppRoutes.game);
  }

  Future<void> _handleUnknown(String rawText) async {
    final msg = await _t(
        'I didn\'t understand that. Try saying something like "Move tube 1 to tube 3", "hint", "undo", or "restart".');
    addMessage(msg);
    speak(msg);
  }

  void _celebrateLevel() {
    playSound('assets/sounds/game_sounds/Puzzle_Solved.mp3');
    Future.delayed(const Duration(milliseconds: 600), () {
      playSound('assets/sounds/game_sounds/Level_Complete.mp3');
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      playSound('assets/sounds/game_sounds/Crowd Applause 01.mp3');
    });

    if (_bsc.currentLevel.value >= BallSortController.kMaxLevels) {
      Future.delayed(const Duration(milliseconds: 200), () {
        playSound('assets/sounds/game_sounds/Firework Explosion 01.mp3');
      });
      _t('Incredible! You\'ve completed Ball Sort Puzzle! '
              'All ${BallSortController.kMaxLevels} levels conquered!')
          .then((msg) {
        addMessage(msg);
        speak(msg);
      });
      _bsc.isGameComplete.value = true;
    } else {
      _t('Level ${_bsc.currentLevel.value} complete! '
              'Say "next" or tap Continue to proceed.')
          .then((msg) {
        addMessage(msg);
        speak(msg);
      });
    }
  }

  Future<void> onIdleTimeout() async {
    playSound('assets/sounds/game_sounds/Go.mp3');
    final msg = await _t('Need a hint? Say "hint" or tap the hint button.');
    addMessage(msg);
    speak(msg);
  }

  Future<String> _smartComment() async {
    const comments = [
      'Nice thinking.',
      'That tube is looking cleaner.',
      'Good strategy.',
      'You\'re getting close!',
      'Excellent move.',
      'One colour sorted — keep going.',
    ];
    final pick = comments[Random().nextInt(comments.length)];
    return await _t(pick);
  }

  Future<Map<String, dynamic>> _parseIntent(String raw) async {
    final lower = _convertWordNumbersToDigits(raw.toLowerCase().trim());

    if (RegExp(r'\bundo\b|go back|reverse|take back').hasMatch(lower))
      return {'action': 'UNDO'};
    if (RegExp(r'\bredo\b|repeat|do again').hasMatch(lower))
      return {'action': 'REDO'};
    if (RegExp(r'\bhint\b|help|clue|suggest').hasMatch(lower))
      return {'action': 'HINT'};
    if (RegExp(r'\brestart\b|reset|start over').hasMatch(lower))
      return {'action': 'RESTART'};
    if (RegExp(r'\bnext\b|continue|proceed').hasMatch(lower))
      return {'action': 'NEXT'};
    if (RegExp(r'\bexit\b|quit|back to hub|leave|close').hasMatch(lower))
      return {'action': 'EXIT'};

    final digits =
        RegExp(r'\d+').allMatches(lower).map((e) => e.group(0)!).toList();
    if (digits.length >= 2 &&
        (lower.contains('move') ||
            lower.contains('tube') ||
            lower.contains('put') ||
            lower.contains('place') ||
            lower.contains('from') ||
            lower.contains('to'))) {
      return {
        'action': 'BALL_MOVE',
        'src': int.parse(digits[0]),
        'dst': int.parse(digits[1]),
      };
    }

    try {
      final translated = await _translateToEnglish(raw);
      if (translated != raw) return _parseIntentSync(translated);
    } catch (_) {}

    return {'action': 'UNKNOWN', 'raw': raw};
  }

  String _convertWordNumbersToDigits(String text) {
    final Map<String, String> wordToNum = {
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'ten': '10',
      'eleven': '11',
      'twelve': '12',
      'thirteen': '13',
      'fourteen': '14',
      'fifteen': '15',
      'sixteen': '16',
      'seventeen': '17',
      'eighteen': '18',
      'nineteen': '19',
      'twenty': '20'
    };
    String result = text;
    wordToNum.forEach((word, num) {
      result = result.replaceAll(
          RegExp(r'\b' + word + r'\b', caseSensitive: false), num);
    });
    return result;
  }

  Map<String, dynamic> _parseIntentSync(String text) {
    final lower = _convertWordNumbersToDigits(text.toLowerCase().trim());

    if (RegExp(r'\bundo\b|go back|reverse|take back').hasMatch(lower))
      return {'action': 'UNDO'};
    if (RegExp(r'\bredo\b|repeat|do again').hasMatch(lower))
      return {'action': 'REDO'};
    if (RegExp(r'\bhint\b|help|clue|suggest').hasMatch(lower))
      return {'action': 'HINT'};
    if (RegExp(r'\brestart\b|reset|start over').hasMatch(lower))
      return {'action': 'RESTART'};
    if (RegExp(r'\bnext\b|continue|proceed').hasMatch(lower))
      return {'action': 'NEXT'};
    if (RegExp(r'\bexit\b|quit|back to hub|leave|close').hasMatch(lower))
      return {'action': 'EXIT'};

    final digits =
        RegExp(r'\d+').allMatches(lower).map((e) => e.group(0)!).toList();
    if (digits.length >= 2 &&
        (lower.contains('move') ||
            lower.contains('tube') ||
            lower.contains('put') ||
            lower.contains('place') ||
            lower.contains('from') ||
            lower.contains('to'))) {
      return {
        'action': 'BALL_MOVE',
        'src': int.parse(digits[0]),
        'dst': int.parse(digits[1]),
      };
    }

    return {'action': 'UNKNOWN', 'raw': lower};
  }

  Future<String> _translateToEnglish(String text) async {
    try {
      final result = await TranslationService.translate(
        text: text,
        targetLanguage: 'en',
      );
      return result.translatedText;
    } catch (_) {
      return text;
    }
  }

  String get _preferredLanguageName {
    try {
      return Get.find<LanguageController>().selectedLanguage.value.name;
    } catch (_) {
      return 'English';
    }
  }

  Future<String> _t(String englishText) async {
    try {
      final langName = _preferredLanguageName;
      if (langName == 'English' ||
          langName == 'English (US)' ||
          langName == 'English (UK)') {
        return englishText;
      }
      final t = await askAISafe(
          'Translate this to $langName purely, keep it natural and conversational. DO NOT add any markdown, quotes, emojis, or introductory text. Just the translation: "$englishText"',
          fallback: englishText);
      return t.replaceAll('"', '');
    } catch (_) {
      return englishText;
    }
  }
}
