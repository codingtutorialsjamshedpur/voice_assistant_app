import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/history_model.dart';
import '../services/ruflo_service.dart';

class HistoryController extends GetxController {
  static HistoryController get to => Get.find<HistoryController>();

  final _storage = GetStorage();
  final _ruflo = RuFloService();
  static const String _storageKey = 'activity_history';

  final RxList<HistoryActivity> allActivities = <HistoryActivity>[].obs;
  final RxList<GroupedHistoryActivities> groupedActivities =
      <GroupedHistoryActivities>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadActivities();
    ever(allActivities, (_) => _groupActivities());
  }

  Future<void> _loadActivities() async {
    try {
      isLoading.value = true;
      final raw = _storage.read<List<dynamic>>(_storageKey) ?? [];
      allActivities.value = raw
          .map((item) =>
              HistoryActivity.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((a) => !a.isDeleted)
          .toList();
      debugPrint('[History] Loaded ${allActivities.length} activities.');
    } catch (e, st) {
      debugPrint('[History] Error loading activities: $e\n$st');
      allActivities.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _saveActivities() async {
    try {
      await _storage.write(
        _storageKey,
        allActivities.map((a) => a.toJson()).toList(),
      );
      debugPrint('[History] Saved ${allActivities.length} activities.');
    } catch (e, st) {
      debugPrint('[History] Error saving activities: $e\n$st');
    }
  }

  void _groupActivities() {
    final now = DateTime.now();

    DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

    final map = <String, List<HistoryActivity>>{};

    for (final activity in allActivities.where((a) => !a.isDeleted)) {
      final diff =
          startOfDay(now).difference(startOfDay(activity.timestamp)).inDays;

      final period = diff == 0
          ? 'Today'
          : diff == 1
              ? 'Yesterday'
              : diff <= 7
                  ? 'Last Week'
                  : diff <= 30
                      ? 'Last Month'
                      : 'Last Year';

      map.putIfAbsent(period, () => []).add(activity);
    }

    map.forEach(
        (_, list) => list.sort((a, b) => b.timestamp.compareTo(a.timestamp)));

    const order = [
      'Today',
      'Yesterday',
      'Last Week',
      'Last Month',
      'Last Year'
    ];
    groupedActivities.value = order
        .where(map.containsKey)
        .map((p) => GroupedHistoryActivities(period: p, activities: map[p]!))
        .toList();

    debugPrint('[History] Grouped into ${groupedActivities.length} periods.');
  }

  Future<List<HistoryActivity>> searchActivities(String query) async {
    try {
      final results = await _ruflo.memorySearch(
        namespace: 'voice_assistant_activities',
        query: query,
        topK: 10,
        threshold: 0.7,
      );
      if (results.isNotEmpty) {
        return results
            .map((r) => HistoryActivity.fromJson(
                Map<String, dynamic>.from(r['value'] as Map)))
            .toList();
      }
    } catch (_) {}

    return allActivities
        .where((a) => a.title.toLowerCase().contains(query.toLowerCase()) ||
            (a.description?.toLowerCase().contains(query.toLowerCase()) ?? false))
        .toList();
  }

  Future<List<HistoryActivity>> getRelevantContext(String currentQuery) async {
    return await searchActivities(currentQuery);
  }

  Future<void> logActivity({
    required ActivityType type,
    required String title,
    String? description,
    String? screenRoute,
    int? durationSeconds,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final activity = HistoryActivity(
        id: const Uuid().v4(),
        type: type,
        title: title,
        description: description,
        timestamp: DateTime.now(),
        screenRoute: screenRoute ?? Get.currentRoute,
        durationSeconds: durationSeconds,
        metadata: metadata,
      );
      allActivities.add(activity);
      await _saveActivities();
      unawaited(_ruflo.memoryStore(
        namespace: 'voice_assistant_activities',
        key: 'activity_${activity.id}',
        value: activity.toJson(),
        metadata: {
          'timestamp': activity.timestamp.millisecondsSinceEpoch,
          'type': activity.type.toString(),
          'screenRoute': activity.screenRoute,
        },
      ));
      debugPrint('[History] Logged: ${activity.title}');
    } catch (e, st) {
      debugPrint('[History] Error logging activity: $e\n$st');
    }
  }

  Future<void> deleteActivity(String activityId) async {
    try {
      final idx = allActivities.indexWhere((a) => a.id == activityId);
      if (idx != -1) {
        allActivities[idx] = allActivities[idx].copyWith(isDeleted: true);
        allActivities.refresh();
        await _saveActivities();
        debugPrint('[History] Deleted activity: $activityId');
      }
    } catch (e, st) {
      debugPrint('[History] Error deleting activity: $e\n$st');
    }
  }

  Future<void> clearAllHistory() async {
    try {
      allActivities.clear();
      await _storage.remove(_storageKey);
      _groupActivities();
      debugPrint('[History] Cleared all history.');
    } catch (e, st) {
      debugPrint('[History] Error clearing history: $e\n$st');
    }
  }
}
