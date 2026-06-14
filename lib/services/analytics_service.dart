import 'dart:async';
import 'package:get/get.dart';
import 'ruflo_service.dart';

class AnalyticsSummary {
  final int totalQueries;
  final double totalCost;
  final double avgLatencyMs;
  final int cacheHits;
  final Map<String, int> modelBreakdown;

  const AnalyticsSummary({
    required this.totalQueries,
    required this.totalCost,
    required this.avgLatencyMs,
    required this.cacheHits,
    required this.modelBreakdown,
  });

  factory AnalyticsSummary.fromRecords(List<Map<String, dynamic>> records) {
    int queries = 0;
    double cost = 0;
    double latencyTotal = 0;
    int cacheHits = 0;
    final models = <String, int>{};

    for (final r in records) {
      queries++;
      cost += (r['cost'] as num?)?.toDouble() ?? 0;
      latencyTotal += (r['latencyMs'] as num?)?.toDouble() ?? 0;
      if (r['cacheHit'] == true) cacheHits++;
      final model = r['model'] as String? ?? 'unknown';
      models[model] = (models[model] ?? 0) + 1;
    }

    return AnalyticsSummary(
      totalQueries: queries,
      totalCost: cost,
      avgLatencyMs: queries > 0 ? latencyTotal / queries : 0,
      cacheHits: cacheHits,
      modelBreakdown: models,
    );
  }
}

class AnalyticsService extends GetxService {
  final _ruflo = RuFloService();

  Future<void> logQuery({
    required String userId,
    required String model,
    required int inputTokens,
    required int outputTokens,
    required int latencyMs,
    required bool cacheHit,
  }) async {
    final cost = _estimateCost(model, inputTokens, outputTokens);

    unawaited(_ruflo.memoryStore(
      namespace: 'analytics_$userId',
      key: 'query_${DateTime.now().millisecondsSinceEpoch}',
      value: {
        'model': model,
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'cost': cost,
        'latencyMs': latencyMs,
        'cacheHit': cacheHit,
        'date': DateTime.now().toIso8601String(),
      },
    ));
  }

  Future<AnalyticsSummary> getWeeklySummary(String userId) async {
    final records = await _ruflo.memorySearch(
      namespace: 'analytics_$userId',
      query: 'query analytics week',
      topK: 500,
    );
    return AnalyticsSummary.fromRecords(records);
  }

  double _estimateCost(String model, int inputTokens, int outputTokens) {
    const pricing = {
      'groq/llama3-8b-instant': 0.00000005,
      'groq/llama3-70b': 0.00000059,
      'claude-3-5-haiku': 0.0000008,
      'claude-sonnet-4-5': 0.000003,
    };
    final rate = pricing[model] ?? 0.000001;
    return (inputTokens + outputTokens) * rate;
  }
}
