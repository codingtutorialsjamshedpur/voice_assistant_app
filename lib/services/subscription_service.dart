import 'package:get/get.dart';
import 'ruflo_service.dart';

class SubscriptionService extends GetxService {
  final _ruflo = RuFloService();

  static const Map<String, int> _dailyLimits = {
    'free': 25,
    'basic': 100,
    'premium': 1000,
    'enterprise': -1,
  };

  Future<bool> canMakeQuery(String userId) async {
    final tier = await _getUserTier(userId);
    final limit = _dailyLimits[tier] ?? 25;
    if (limit == -1) return true;

    final usage = await _getTodayUsage(userId);
    return usage < limit;
  }

  Future<String> _getUserTier(String userId) async {
    try {
      final result = await _ruflo.memorySearch(
        namespace: 'user_tiers',
        query: userId,
        topK: 1,
      );
      if (result.isNotEmpty) {
        return result.first['tier'] as String? ?? 'free';
      }
    } catch (_) {}
    return 'free';
  }

  Future<int> _getTodayUsage(String userId) async {
    try {
      final records = await _ruflo.memorySearch(
        namespace: 'analytics_$userId',
        query: 'query today usage count',
        topK: 1000,
      );
      final today = DateTime.now();
      return records.where((r) {
        final date = DateTime.tryParse(r['date'] as String? ?? '');
        return date != null &&
            date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
      }).length;
    } catch (_) {
      return 0;
    }
  }
}
