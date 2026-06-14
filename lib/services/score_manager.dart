import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ScoreManager extends GetxService {
  final _box = GetStorage();

  static const _kCurrentLevel = 'bsp_current_level';
  static const _kBestScore = 'bsp_best_score';
  static const _kTotalMoves = 'bsp_total_moves';
  static const _kHintsUsed = 'bsp_hints_used';

  // Score logic removed as per requirements

  void saveLevelProgress({
    required int level,
    required int moves,
    required int hints,
  }) {
    _box.write(_kCurrentLevel, level);
    _box.write(_kTotalMoves, (_box.read(_kTotalMoves) ?? 0) + moves);
    _box.write(_kHintsUsed, (_box.read(_kHintsUsed) ?? 0) + hints);
  }

  int loadSavedLevel() => _box.read<int>(_kCurrentLevel) ?? 1;

  void clearProgress() {
    _box.remove(_kCurrentLevel);
    _box.remove(_kBestScore);
    _box.remove(_kTotalMoves);
    _box.remove(_kHintsUsed);
  }
}
