import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/level_generator_service.dart';
import '../services/score_manager.dart';
import '../services/sound_manager.dart';

class BallColor {
  static const Map<String, Color> palette = {
    'red': Color(0xFFFF3B30),
    'blue': Color(0xFF007AFF),
    'green': Color(0xFF34C759),
    'yellow': Color(0xFFFFCC00),
    'pink': Color(0xFFFF2D55),
    'orange': Color(0xFFFF9500),
    'purple': Color(0xFF5856D6),
    'teal': Color(0xFF5AC8FA),
    'cyan': Color(0xFF00FFFF),
    'lime': Color(0xFFBFFF00),
    'brown': Color(0xFF8B4513),
    'grey': Color(0xFF808080),
  };
}

class Tube {
  final int capacity;
  List<String> balls;

  Tube({this.capacity = 4, List<String>? balls}) : balls = balls ?? [];

  bool get isEmpty => balls.isEmpty;
  bool get isFull => balls.length >= capacity;
  String? get topBall => balls.isEmpty ? null : balls.last;
  bool get isComplete => balls.length == capacity && balls.toSet().length == 1;

  Tube copyWith({List<String>? balls}) =>
      Tube(capacity: capacity, balls: balls ?? List.from(this.balls));
}

class MoveSnapshot {
  final List<Tube> tubes;
  final int sourceTubeIndex;
  final int destTubeIndex;
  final int segmentsMoved;
  MoveSnapshot({
    required this.tubes,
    required this.sourceTubeIndex,
    required this.destTubeIndex,
    this.segmentsMoved = 1,
  });
}

class LevelConfig {
  final int numColors;
  final int emptyTubes;
  final int minMoves;
  final int maxMoves;

  const LevelConfig({
    required this.numColors,
    required this.emptyTubes,
    required this.minMoves,
    required this.maxMoves,
  });
}

class BallSortController extends GetxController {
  final LevelGeneratorService _levelService = Get.find<LevelGeneratorService>();
  final ScoreManager _scoreManager = Get.find<ScoreManager>();
  final SoundManager _soundManager = Get.find<SoundManager>();

  final RxList<Tube> tubes = <Tube>[].obs;
  final RxInt currentLevel = 1.obs;
  final RxInt moveCount = 0.obs;
  final RxInt elapsedSeconds = 0.obs;
  final RxBool isPaused = false.obs;
  final RxBool isLevelComplete = false.obs;
  final RxBool isGameComplete = false.obs;
  final RxBool isGameOver = false.obs;
  final RxInt selectedTubeIndex = RxInt(-1);
  final RxList<int> hintHighlight = <int>[].obs;
  final RxInt hintsUsed = 0.obs;
  final RxInt undosUsed = 0.obs;
  final RxInt maxAllowedMoves = 0.obs;
  final RxInt optimalMoves = 0.obs;
  final RxString performanceRating = ''.obs;
  final RxInt starCount = 0.obs;

  final RxBool isAnimating = false.obs;
  int animSrcIndex = -1;
  int animDstIndex = -1;
  String animBallColor = '';
  int animSegmentsToPour = 1;

  bool get canUndo => !isAnimating.value && _undoStack.isNotEmpty;
  bool get canRedo => !isAnimating.value && _redoStack.isNotEmpty;
  bool get isLiquidMode => _levelService.isLiquidLevel(currentLevel.value);

  /// Returns how many same-color top balls can be transferred in a single
  /// pour from [srcIndex] to [dstIndex]. Used by the liquid-pour animation
  /// to know how many segments to draw in one continuous motion.
  int maxPourCount(int srcIndex, int dstIndex) {
    if (srcIndex == dstIndex) return 0;
    if (srcIndex < 0 || srcIndex >= tubes.length) return 0;
    if (dstIndex < 0 || dstIndex >= tubes.length) return 0;
    final src = tubes[srcIndex];
    final dst = tubes[dstIndex];
    if (src.isEmpty) return 0;
    if (dst.isFull) return 0;
    if (!dst.isEmpty && dst.topBall != src.topBall) return 0;

    final color = src.topBall!;
    final freeSlots = dst.capacity - dst.balls.length;
    int count = 0;
    for (int i = src.balls.length - 1; i >= 0; i--) {
      if (src.balls[i] != color) break;
      count++;
      if (count >= freeSlots) break;
    }
    return count;
  }

  /// Epoch millis of the most recent user interaction (move, undo,
  /// redo, hint, restart, tube tap). Watched by widgets to decide
  /// when to start idle anticipation animations.
  final RxInt lastInteractionMs = 0.obs;

  final List<MoveSnapshot> _undoStack = [];
  final List<MoveSnapshot> _redoStack = [];

  Timer? _gameTimer;
  Timer? _idleTimer;

  /// 40 hand-tuned structured levels (1–20 Ball mode, 21–40 Liquid).
  /// Levels beyond this reuse the hardest definition.
  static const int kMaxLevels = 40;
  static const int kTubeCapacity = 4;

  VoidCallback? onIdleTimeout;
  VoidCallback? onMoveCompleted;

  void startLevel(int level) {
    currentLevel.value = level;
    moveCount.value = 0;
    hintsUsed.value = 0;
    undosUsed.value = 0;
    isLevelComplete.value = false;
    isGameComplete.value = false;
    isGameOver.value = false;
    selectedTubeIndex.value = -1;
    hintHighlight.clear();
    _undoStack.clear();
    _redoStack.clear();
    starCount.value = 0;
    lastInteractionMs.value = DateTime.now().millisecondsSinceEpoch;

    final generatedLevel = _levelService.generateLevel(level);
    optimalMoves.value = generatedLevel.optimalMoves;
    maxAllowedMoves.value = (generatedLevel.optimalMoves * 1.5).ceil();

    tubes.assignAll(generatedLevel.tubes);
    _soundManager.playGameSound(GameSound.getReady);
    _soundManager.startBackgroundMusic();

    _startTimer();
    _resetIdleTimer();
  }

  void _markInteraction() {
    lastInteractionMs.value = DateTime.now().millisecondsSinceEpoch;
  }

  bool tryMove(int srcIndex, int dstIndex) {
    if (srcIndex == dstIndex) return false;

    final src = tubes[srcIndex];
    final dst = tubes[dstIndex];

    if (src.isEmpty) return false;
    if (dst.isFull) return false;
    if (!dst.isEmpty && dst.topBall != src.topBall) return false;

    final n = maxPourCount(srcIndex, dstIndex);
    if (n <= 0) return false;

    _undoStack.add(MoveSnapshot(
      tubes: tubes.map((t) => t.copyWith()).toList(),
      sourceTubeIndex: srcIndex,
      destTubeIndex: dstIndex,
      segmentsMoved: n,
    ));
    _redoStack.clear();

    for (int i = 0; i < n; i++) {
      dst.balls.add(src.balls.removeLast());
    }
    tubes.refresh();

    moveCount.value++;
    selectedTubeIndex.value = -1;
    _markInteraction();

    _soundManager.playGameSound(GameSound.ballMove);
    _resetIdleTimer();
    _checkLevelComplete();
    _checkGameOver();
    onMoveCompleted?.call();
    return true;
  }

  bool prepareMove(int srcIndex, int dstIndex) {
    if (srcIndex == dstIndex) return false;

    final src = tubes[srcIndex];
    final dst = tubes[dstIndex];

    if (src.isEmpty) return false;
    if (dst.isFull) return false;
    if (!dst.isEmpty && dst.topBall != src.topBall) return false;

    final n = maxPourCount(srcIndex, dstIndex);
    if (n <= 0) return false;

    animSrcIndex = srcIndex;
    animDstIndex = dstIndex;
    animBallColor = src.topBall!;
    animSegmentsToPour = n;
    isAnimating.value = true;
    _soundManager.playGameSound(GameSound.liquidPour);
    return true;
  }

  void completePendingMove() {
    if (animSrcIndex < 0) return;

    _undoStack.add(MoveSnapshot(
      tubes: tubes.map((t) => t.copyWith()).toList(),
      sourceTubeIndex: animSrcIndex,
      destTubeIndex: animDstIndex,
      segmentsMoved: animSegmentsToPour,
    ));
    _redoStack.clear();

    for (int i = 0; i < animSegmentsToPour; i++) {
      tubes[animDstIndex].balls.add(tubes[animSrcIndex].balls.removeLast());
    }
    tubes.refresh();

    moveCount.value++;
    selectedTubeIndex.value = -1;
    _markInteraction();

    animSrcIndex = -1;
    animDstIndex = -1;
    animBallColor = '';
    animSegmentsToPour = 1;
    isAnimating.value = false;

    _resetIdleTimer();
    _checkLevelComplete();
    _checkGameOver();
    onMoveCompleted?.call();
  }

  void undo() {
    if (canUndo == false) return;
    undosUsed.value++;
    _soundManager.playGameSound(GameSound.undoReverse);
    _markInteraction();
    final snap = _undoStack.removeLast();
    _redoStack.add(MoveSnapshot(
      tubes: tubes.map((t) => t.copyWith()).toList(),
      sourceTubeIndex: snap.destTubeIndex,
      destTubeIndex: snap.sourceTubeIndex,
    ));
    _restoreSnapshot(snap);
    moveCount.value = max(0, moveCount.value - 1);
  }

  void redo() {
    if (canRedo == false) return;
    _markInteraction();
    final snap = _redoStack.removeLast();
    _undoStack.add(snap);
    _restoreSnapshot(snap);
    moveCount.value++;
  }

  void _restoreSnapshot(MoveSnapshot snap) {
    for (int i = 0; i < tubes.length; i++) {
      tubes[i].balls = List.from(snap.tubes[i].balls);
    }
    tubes.refresh();
  }

  void restartLevel() {
    startLevel(currentLevel.value);
  }

  void loadNextLevel() {
    startLevel(currentLevel.value + 1);
  }

  final RxInt ambientTrack = 0.obs;

  void toggleAmbient() {
    ambientTrack.value = (ambientTrack.value + 1) % 4;
  }

  void _checkGameOver() {
    if (moveCount.value <= maxAllowedMoves.value || isLevelComplete.value) {
      return;
    }
    // Only declare GAME OVER when the puzzle is truly unsolvable
    // from the current state. If at least one legal move still exists,
    // the player must be allowed to keep playing — even if they have
    // used more than the suggested number of moves. This prevents the
    // game from getting stuck in a locked state near completion.
    if (getSilentHint() != null) {
      return;
    }
    isGameOver.value = true;
    _stopTimer();
    performanceRating.value = 'GAME OVER';
    starCount.value = 0;
    _soundManager.playGameSound(GameSound.gameOver, duck: true);
  }

  void _checkLevelComplete() {
    final allComplete =
        tubes.where((t) => !t.isEmpty).every((t) => t.isComplete);
    if (allComplete) {
      _stopTimer();
      _scoreManager.saveLevelProgress(
        level: currentLevel.value,
        moves: moveCount.value,
        hints: hintsUsed.value,
      );
      isLevelComplete.value = true;

      // Determine rating, star count, and matching sound.
      //   3 stars (★★★ INCREDIBLE!)  = solved in optimal moves
      //   2 stars (★★ EXCELLENT!)     = optimal + 1..2 moves
      //   1 star  (★ GOOD!)            = solved within max-allowed
      final used = moveCount.value;
      final opt = optimalMoves.value;
      if (used <= opt) {
        performanceRating.value = 'INCREDIBLE!';
        starCount.value = 3;
        _soundManager.playGameSound(GameSound.ratingIncredible, duck: true);
      } else if (used <= opt + 2) {
        performanceRating.value = 'EXCELLENT!';
        starCount.value = 2;
        _soundManager.playGameSound(GameSound.ratingExcellent, duck: true);
      } else {
        performanceRating.value = 'GOOD!';
        starCount.value = 1;
        _soundManager.playGameSound(GameSound.ratingGood, duck: true);
      }
      _soundManager.playGameSound(GameSound.levelComplete);
    }
  }

  List<int>? computeHint() {
    _soundManager.playGameSound(GameSound.hint, duck: true);
    hintsUsed.value++;
    return getSilentHint();
  }

  List<int>? getSilentHint() {
    for (int s = 0; s < tubes.length; s++) {
      if (tubes[s].isEmpty) continue;
      for (int d = 0; d < tubes.length; d++) {
        if (s == d) continue;
        if (tubes[d].isFull) continue;
        if (!tubes[d].isEmpty && tubes[d].topBall != tubes[s].topBall) continue;
        if (!tubes[d].isEmpty || _wouldConsolidate(s, d)) {
          return [s, d];
        }
      }
    }
    for (int s = 0; s < tubes.length; s++) {
      if (tubes[s].isEmpty) continue;
      for (int d = 0; d < tubes.length; d++) {
        if (s == d || tubes[d].isFull) continue;
        if (!tubes[d].isEmpty && tubes[d].topBall != tubes[s].topBall) continue;
        return [s, d];
      }
    }
    return null;
  }

  bool _wouldConsolidate(int src, int dst) {
    final color = tubes[src].topBall!;
    return tubes[dst].balls.where((b) => b == color).length >= 2;
  }

  int loadSavedLevel() => _scoreManager.loadSavedLevel();

  void clearProgress() {
    _scoreManager.clearProgress();
    startLevel(1);
  }

  void _startTimer() {
    _gameTimer?.cancel();
    elapsedSeconds.value = 0;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isPaused.value) {
        elapsedSeconds.value++;
      }
    });
  }

  void _stopTimer() {
    _gameTimer?.cancel();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 25), () {
      _soundManager.playGameSound(GameSound.idleRooster);
      onIdleTimeout?.call();
    });
  }

  void onTubeTap(int index) {
    if (isLevelComplete.value ||
        isGameComplete.value ||
        isGameOver.value ||
        isAnimating.value) {
      return;
    }

    if (selectedTubeIndex.value == -1) {
      if (!tubes[index].isEmpty) {
        selectedTubeIndex.value = index;
        _markInteraction();
        _soundManager.playGameSound(GameSound.buttonClick);
      }
    } else {
      final src = selectedTubeIndex.value;
      if (src == index) {
        selectedTubeIndex.value = -1;
        _markInteraction();
      } else {
        _markInteraction();
        prepareMove(src, index);
      }
    }
  }

  @override
  void onClose() {
    _stopTimer();
    _idleTimer?.cancel();
    _soundManager.stopAll();
    super.onClose();
  }
}
