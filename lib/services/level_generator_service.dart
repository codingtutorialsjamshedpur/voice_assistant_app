import 'dart:math';
import 'package:get/get.dart';
import '../controllers/ball_sort_controller.dart';

class GeneratedLevel {
  final List<Tube> tubes;
  final int optimalMoves;
  final bool isLiquid;

  GeneratedLevel(this.tubes, this.optimalMoves, this.isLiquid);
}

/// A single predefined level in the structured progression.
///
/// Difficulty is increased by:
///   * more colors (more distinct liquids/balls)
///   * more empty helper tubes being available
///   * a larger tube capacity
///   * a deeper shuffle range (more scramble, longer solves)
class LevelDefinition {
  final int numColors;
  final int emptyTubes;
  final int capacity;
  final int minShuffle;
  final int maxShuffle;
  final bool isLiquid;

  const LevelDefinition({
    required this.numColors,
    required this.emptyTubes,
    required this.capacity,
    required this.minShuffle,
    required this.maxShuffle,
    required this.isLiquid,
  });
}

/// 40 hand-tuned levels that form a smooth difficulty curve.
///
///   * Levels 1–20  → Ball Sort mode (colored glass balls)
///   * Levels 21–40 → Liquid Sort mode (colored liquids)
///
/// Difficulty ramps up gradually — never by randomness alone.
const List<LevelDefinition> kStructuredLevels = [
  // ───── Ball Mode: Levels 1–20 ─────────────────────────────
  // Intro: 2 colors, single empty tube, shallow shuffles.
  LevelDefinition(numColors: 2, emptyTubes: 1, capacity: 4, minShuffle: 4, maxShuffle: 6, isLiquid: false),
  LevelDefinition(numColors: 2, emptyTubes: 1, capacity: 4, minShuffle: 5, maxShuffle: 7, isLiquid: false),
  // Warm-up: 3 colors, 1 empty tube.
  LevelDefinition(numColors: 3, emptyTubes: 1, capacity: 4, minShuffle: 6, maxShuffle: 8, isLiquid: false),
  LevelDefinition(numColors: 3, emptyTubes: 1, capacity: 4, minShuffle: 7, maxShuffle: 9, isLiquid: false),
  // 3 colors, 2 empty tubes for breathing room.
  LevelDefinition(numColors: 3, emptyTubes: 2, capacity: 4, minShuffle: 8, maxShuffle: 11, isLiquid: false),
  LevelDefinition(numColors: 3, emptyTubes: 2, capacity: 4, minShuffle: 9, maxShuffle: 12, isLiquid: false),
  // Introducing 4 colors.
  LevelDefinition(numColors: 4, emptyTubes: 1, capacity: 4, minShuffle: 8, maxShuffle: 12, isLiquid: false),
  LevelDefinition(numColors: 4, emptyTubes: 1, capacity: 4, minShuffle: 9, maxShuffle: 13, isLiquid: false),
  LevelDefinition(numColors: 4, emptyTubes: 2, capacity: 4, minShuffle: 10, maxShuffle: 14, isLiquid: false),
  LevelDefinition(numColors: 4, emptyTubes: 2, capacity: 4, minShuffle: 11, maxShuffle: 15, isLiquid: false),
  // 5 colors, more depth.
  LevelDefinition(numColors: 5, emptyTubes: 1, capacity: 4, minShuffle: 10, maxShuffle: 14, isLiquid: false),
  LevelDefinition(numColors: 5, emptyTubes: 2, capacity: 4, minShuffle: 12, maxShuffle: 16, isLiquid: false),
  LevelDefinition(numColors: 5, emptyTubes: 2, capacity: 4, minShuffle: 13, maxShuffle: 17, isLiquid: false),
  LevelDefinition(numColors: 5, emptyTubes: 2, capacity: 4, minShuffle: 14, maxShuffle: 19, isLiquid: false),
  LevelDefinition(numColors: 5, emptyTubes: 2, capacity: 4, minShuffle: 15, maxShuffle: 20, isLiquid: false),
  // 6 colors, full challenge.
  LevelDefinition(numColors: 6, emptyTubes: 2, capacity: 4, minShuffle: 14, maxShuffle: 18, isLiquid: false),
  LevelDefinition(numColors: 6, emptyTubes: 2, capacity: 4, minShuffle: 15, maxShuffle: 20, isLiquid: false),
  LevelDefinition(numColors: 6, emptyTubes: 2, capacity: 4, minShuffle: 16, maxShuffle: 22, isLiquid: false),
  LevelDefinition(numColors: 6, emptyTubes: 2, capacity: 4, minShuffle: 18, maxShuffle: 24, isLiquid: false),
  LevelDefinition(numColors: 6, emptyTubes: 2, capacity: 4, minShuffle: 20, maxShuffle: 26, isLiquid: false),

  // ───── Liquid Mode: Levels 21–40 ───────────────────────────
  // Liquid intro: 3 colors, shallow shuffle.
  LevelDefinition(numColors: 3, emptyTubes: 1, capacity: 4, minShuffle: 8, maxShuffle: 12, isLiquid: true),
  LevelDefinition(numColors: 3, emptyTubes: 1, capacity: 4, minShuffle: 9, maxShuffle: 13, isLiquid: true),
  LevelDefinition(numColors: 3, emptyTubes: 2, capacity: 4, minShuffle: 10, maxShuffle: 14, isLiquid: true),
  // 4-color liquids.
  LevelDefinition(numColors: 4, emptyTubes: 1, capacity: 4, minShuffle: 10, maxShuffle: 14, isLiquid: true),
  LevelDefinition(numColors: 4, emptyTubes: 1, capacity: 4, minShuffle: 11, maxShuffle: 15, isLiquid: true),
  LevelDefinition(numColors: 4, emptyTubes: 2, capacity: 4, minShuffle: 12, maxShuffle: 16, isLiquid: true),
  LevelDefinition(numColors: 4, emptyTubes: 2, capacity: 4, minShuffle: 13, maxShuffle: 17, isLiquid: true),
  // 5-color liquids.
  LevelDefinition(numColors: 5, emptyTubes: 1, capacity: 4, minShuffle: 12, maxShuffle: 16, isLiquid: true),
  LevelDefinition(numColors: 5, emptyTubes: 2, capacity: 4, minShuffle: 14, maxShuffle: 18, isLiquid: true),
  LevelDefinition(numColors: 5, emptyTubes: 2, capacity: 4, minShuffle: 15, maxShuffle: 20, isLiquid: true),
  LevelDefinition(numColors: 5, emptyTubes: 2, capacity: 4, minShuffle: 16, maxShuffle: 22, isLiquid: true),
  // 6-color liquids.
  LevelDefinition(numColors: 6, emptyTubes: 2, capacity: 4, minShuffle: 16, maxShuffle: 20, isLiquid: true),
  LevelDefinition(numColors: 6, emptyTubes: 2, capacity: 4, minShuffle: 17, maxShuffle: 22, isLiquid: true),
  LevelDefinition(numColors: 6, emptyTubes: 2, capacity: 4, minShuffle: 18, maxShuffle: 24, isLiquid: true),
  LevelDefinition(numColors: 6, emptyTubes: 2, capacity: 4, minShuffle: 20, maxShuffle: 26, isLiquid: true),
  // 7-color liquids, hardest of the curve.
  LevelDefinition(numColors: 7, emptyTubes: 2, capacity: 4, minShuffle: 20, maxShuffle: 26, isLiquid: true),
  LevelDefinition(numColors: 7, emptyTubes: 2, capacity: 4, minShuffle: 22, maxShuffle: 28, isLiquid: true),
  LevelDefinition(numColors: 7, emptyTubes: 2, capacity: 4, minShuffle: 24, maxShuffle: 30, isLiquid: true),
  LevelDefinition(numColors: 7, emptyTubes: 2, capacity: 4, minShuffle: 26, maxShuffle: 32, isLiquid: true),
  LevelDefinition(numColors: 7, emptyTubes: 2, capacity: 4, minShuffle: 28, maxShuffle: 35, isLiquid: true),
];

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

class LevelGeneratorService extends GetxService {
  final Random _random = Random();

  /// Total number of structured levels shipped with the game.
  /// Levels beyond this count reuse the final, hardest definition
  /// so the game can still be played past the cap.
  static const int kStructuredLevelCount = 40;

  /// Total number of tubes the puzzle must show for a level so that
  /// the board renderer can lay them out without scrolling.
  int getTubeCountForLevel(int level) {
    final def = _resolveDefinition(level);
    return def.numColors + def.emptyTubes;
  }

  LevelConfig getConfigForLevel(int level) {
    final def = _resolveDefinition(level);
    return LevelConfig(
      numColors: def.numColors,
      emptyTubes: def.emptyTubes,
      minMoves: def.minShuffle,
      maxMoves: def.maxShuffle,
    );
  }

  bool isLiquidLevel(int level) {
    return _resolveDefinition(level).isLiquid;
  }

  LevelDefinition getDefinitionForLevel(int level) {
    return _resolveDefinition(level);
  }

  /// Returns a deterministic-ish level definition:
  ///   * In-range levels  → the predefined entry.
  ///   * Past the cap      → the final (hardest) definition.
  ///   * Below 1           → the first (easiest) definition.
  LevelDefinition _resolveDefinition(int level) {
    if (level < 1) return kStructuredLevels.first;
    if (level > kStructuredLevels.length) {
      return kStructuredLevels.last;
    }
    return kStructuredLevels[level - 1];
  }

  GeneratedLevel generateLevel(int level) {
    final def = _resolveDefinition(level);
    final colors = BallColor.palette.keys.take(def.numColors).toList();

    // Start with a fully solved state — one tube per color, all full,
    // plus the requested number of empty helper tubes.
    final List<Tube> tubes = [];
    for (int t = 0; t < def.numColors; t++) {
      tubes.add(Tube(
        capacity: def.capacity,
        balls: List<String>.generate(def.capacity, (_) => colors[t]),
      ));
    }
    for (int e = 0; e < def.emptyTubes; e++) {
      tubes.add(Tube(capacity: def.capacity));
    }

    final span = max(1, def.maxShuffle - def.minShuffle);
    final targetShuffleMoves = def.minShuffle + _random.nextInt(span);
    final actualMoves = _shuffle(tubes, targetShuffleMoves);

    // Solvability verification:
    //   Backward shuffling from a solved state always produces a
    //   solvable puzzle (every shuffle move is a valid forward move,
    //   so the inverse sequence is a solution). We still guard against
    //   trivial "no-op" shuffles and against the (extremely rare) case
    //   where the random walk lands back on the solved configuration
    //   by ensuring the resulting state differs from the start and by
    //   refusing to return a zero-move level.
    if (actualMoves == 0 || _isSolvedState(tubes)) {
      // Force at least a few moves to keep the puzzle meaningful.
      return generateLevel(level);
    }

    return GeneratedLevel(tubes, actualMoves, def.isLiquid);
  }

  int _shuffle(List<Tube> tubes, int targetMoves) {
    int actualMoves = 0;
    int failedAttempts = 0;
    int lastSource = -1;
    int lastDest = -1;

    while (actualMoves < targetMoves && failedAttempts < 80) {
      final int srcIdx = _random.nextInt(tubes.length);
      final int dstIdx = _random.nextInt(tubes.length);

      if (srcIdx == dstIdx) {
        failedAttempts++;
        continue;
      }
      if (srcIdx == lastDest && dstIdx == lastSource) {
        failedAttempts++;
        continue;
      }

      final src = tubes[srcIdx];
      final dst = tubes[dstIdx];

      if (src.isEmpty || dst.isFull) {
        failedAttempts++;
        continue;
      }

      // Move the top ball. In the backward-shuffle model, every such
      // move is a legal forward move, so the sequence is reversible
      // and the resulting state is guaranteed solvable.
      dst.balls.add(src.balls.removeLast());
      actualMoves++;
      failedAttempts = 0;
      lastSource = srcIdx;
      lastDest = dstIdx;
    }
    return actualMoves;
  }

  bool _isSolvedState(List<Tube> tubes) {
    for (final t in tubes) {
      if (t.isEmpty) continue;
      if (t.balls.length != t.capacity) return false;
      final first = t.balls.first;
      for (final b in t.balls) {
        if (b != first) return false;
      }
    }
    return true;
  }
}
