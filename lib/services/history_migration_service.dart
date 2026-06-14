import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../controllers/history_controller.dart' show HistoryController;
import 'ruflo_service.dart';

class HistoryMigrationService extends GetxService {
  final _ruflo = RuFloService();
  final _storage = GetStorage();
  static const String _migrationKey = 'history_migrated_to_agentdb';

  Future<bool> isMigrationNeeded() async {
    return !(_storage.read(_migrationKey) ?? false);
  }

  Future<void> migrateToAgentDB() async {
    if (!await isMigrationNeeded()) return;

    try {
      final controller = Get.find<HistoryController>();
      final activities = controller.allActivities.toList();
      int migrated = 0;

      for (final activity in activities) {
        try {
          await _ruflo.memoryStore(
            namespace: 'voice_assistant_activities',
            key: 'activity_${activity.id}',
            value: activity.toJson(),
            metadata: {
              'timestamp': activity.timestamp.millisecondsSinceEpoch,
              'type': activity.type.toString(),
              'migrated': true,
            },
          );
          migrated++;
        } catch (_) {}
      }

      await _storage.write(_migrationKey, true);
      print('[Migration] Migrated $migrated/${activities.length} activities to AgentDB');
    } catch (e) {
      print('[Migration] Error: $e');
    }
  }

  Future<void> resetMigrationFlag() async {
    await _storage.remove(_migrationKey);
  }
}
