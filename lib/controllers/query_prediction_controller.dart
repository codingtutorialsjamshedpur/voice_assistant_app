import 'package:get/get.dart';
import '../models/query_item.dart';
import '../data/category_keywords.dart';
import '../services/ruflo_service.dart';
import 'voice_controller.dart';
import 'voice_assistant_game_controller.dart';

/// Holds the complete session-level prediction state.
/// All data is in-memory only — no persistence anywhere.
class QueryPredictionController extends GetxController {
  // ── Data Structures ────────────────────────────────────────────────────

  /// CircularBuffer: last 10 queries only. Auto-drops oldest when full.
  final RxList<QueryItem> queryBuffer = <QueryItem>[].obs;
  static const int _maxBufferSize = 10;

  /// HashMap<category, count>: frequency of each category this session.
  final RxMap<String, int> categoryFreqMap = <String, int>{}.obs;

  /// Sparse co-occurrence matrix: {catA: {catB: count}}.
  /// Tracks which categories appear together.
  final Map<String, Map<String, int>> _coMatrix = {};

  /// Pair queue: holds at most 2 QueryItems (A and B).
  /// Resets after every derivation cycle.
  final List<QueryItem> _pairQueue = [];

  /// Bloom-filter-like Set: stores hashes of already-shown suggestions.
  /// Prevents showing the same suggestion twice in one session.
  final Set<String> _shownSuggestions = {};

  /// Total queries made in this session.
  final RxInt totalQueries = 0.obs;

  // ── Reactive output ────────────────────────────────────────────────────

  /// The suggestions to display on the voice chat screen.
  /// Widgets observe this list via Obx or GetBuilder.
  final RxList<SuggestionResult> currentSuggestions = <SuggestionResult>[].obs;

  /// Current phase (1, 2, or 3). Updates automatically.
  final RxInt currentPhase = 1.obs;

  // ── Public API ─────────────────────────────────────────────────────────

  /// Call this every time the user submits a voice or text query.
  /// [queryText] is the raw query string from the user.
  void onUserQuery(String queryText) {
    final trimmed = queryText.trim();
    if (trimmed.isEmpty) return;

    final category = _categorize(trimmed);
    final item = QueryItem(
      text: trimmed,
      category: category,
      timestamp: DateTime.now(),
    );

    _addToBuffer(item);
    _updateFreqMap(category);
    _updateCoMatrix(item);
    _addToPairQueue(item);

    totalQueries.value++;
    currentPhase.value = _computePhase();

    // Clear old suggestions immediately upon new query
    currentSuggestions.clear();

    // Asynchronously call RuFlo Swarm to predict dynamic follow-up questions
    // This is now purely dynamic, powered 100% by the cloud Swarm brain.
    _requestSwarmPredictions(trimmed);
  }

  Future<void> _requestSwarmPredictions(String lastUserText) async {
    try {
      if (!Get.isRegistered<RuFloService>()) return;

      String activePersona = 'Unknown API';
      if (Get.isRegistered<VoiceAssistantGameController>()) {
        activePersona = 'Palak (Game Screen)';
      } else if (Get.isRegistered<VoiceController>()) {
        activePersona =
            Get.find<VoiceController>().currentPersonalityPack.value.name;
      }

      final history = queryBuffer.map((q) => q.text).toList();

      final result = await Get.find<RuFloService>().swarmQuery(
          input:
              'User asked: "$lastUserText". Generate 2 highly dynamic, curious follow-up questions they could ask $activePersona next.',
          agents: [
            'curiosity_predictor'
          ],
          context: {
            'persona': activePersona,
            'history': history,
          });

      if (result.containsKey('suggestions')) {
        final dynSuggestions = result['suggestions'] as List<dynamic>;
        for (var s in dynSuggestions) {
          final textString = s.toString().replaceAll('"', '');
          if (_notShown(textString)) {
            currentSuggestions.insert(
                0,
                SuggestionResult(
                    label: 'Dynamic AI',
                    text: textString,
                    type: SuggestionType.cluster));
            _markShown(textString);
          }
        }
      }
    } catch (e) {
      print('Swarm Prediction Error: $e');
    }
  }

  /// Wipe all session data. Call when user taps the delete/reset button.
  void resetSession() {
    queryBuffer.clear();
    categoryFreqMap.clear();
    _coMatrix.clear();
    _pairQueue.clear();
    _shownSuggestions.clear();
    currentSuggestions.clear();
    totalQueries.value = 0;
    currentPhase.value = 1;
  }

  // ── Interest Vector (read-only computed) ──────────────────────────────

  /// Returns categories sorted by interest weight, highest first.
  /// Each entry is {category, weight (0.0–1.0), count}.
  List<Map<String, dynamic>> get interestVector {
    final total = categoryFreqMap.values.fold(0, (a, b) => a + b);
    if (total == 0) return [];
    return categoryFreqMap.entries
        .map((e) => {
              'category': e.key,
              'count': e.value,
              'weight': e.value / total,
            })
        .toList()
      ..sort(
          (a, b) => (b['weight'] as double).compareTo(a['weight'] as double));
  }

  // ── Private: data structure operations ────────────────────────────────

  void _addToBuffer(QueryItem item) {
    queryBuffer.add(item);
    if (queryBuffer.length > _maxBufferSize) {
      queryBuffer.removeAt(0); // drop oldest (circular behaviour)
    }
  }

  void _updateFreqMap(String category) {
    categoryFreqMap[category] = (categoryFreqMap[category] ?? 0) + 1;
  }

  void _updateCoMatrix(QueryItem incoming) {
    if (_pairQueue.isEmpty) return;
    final prev = _pairQueue.last;
    final catA = prev.category;
    final catB = incoming.category;
    if (catA == catB) return;

    _coMatrix[catA] ??= {};
    _coMatrix[catB] ??= {};
    _coMatrix[catA]![catB] = (_coMatrix[catA]![catB] ?? 0) + 1;
    _coMatrix[catB]![catA] = (_coMatrix[catB]![catA] ?? 0) + 1;
  }

  void _addToPairQueue(QueryItem item) {
    _pairQueue.add(item);
    if (_pairQueue.length > 2) _pairQueue.removeAt(0);
  }

  int _computePhase() {
    if (totalQueries.value < 2) return 1;
    if (totalQueries.value < 5) return 2;
    return 3;
  }

  // ── Private: categorizer ───────────────────────────────────────────────

  /// Counts keyword matches per category. Returns highest-scoring category.
  /// Falls back to 'general' if no keywords match.
  String _categorize(String query) {
    final lower = query.toLowerCase();
    String bestCategory = 'general';
    int bestScore = 0;

    for (final entry in categoryKeywords.entries) {
      final score = entry.value.where((kw) => lower.contains(kw)).length;
      if (score > bestScore) {
        bestScore = score;
        bestCategory = entry.key;
      }
    }
    return bestCategory;
  }

  // (Old static derivation methods removed in favor of RuFlo Swarm intelligence)

  bool _notShown(String text) =>
      !_shownSuggestions.contains(text.hashCode.toString());
  void _markShown(String text) =>
      _shownSuggestions.add(text.hashCode.toString());
}

// ── Value objects ──────────────────────────────────────────────────────────

enum SuggestionType { bridge, depthA, depthB, cluster }

class SuggestionResult {
  final String label;
  final String text;
  final SuggestionType type;

  const SuggestionResult({
    required this.label,
    required this.text,
    required this.type,
  });
}
