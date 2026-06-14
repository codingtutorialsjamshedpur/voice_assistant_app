import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/history_controller.dart';
import '../../routes/app_routes.dart';
import '../../services/sound_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import '../../shared/widgets/glassmorphic_dialog.dart';
import 'widgets/history_card.dart';
import '../../controllers/interstitial_ad_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryController _ctrl;
  int _itemTapCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(HistoryController());
  }

  Future<void> _deleteActivity(String id) async {
    await _ctrl.deleteActivity(id);
  }

  Future<void> _clearAllHistory() async {
    await GlassmorphicDialogHelper.showDeleteConfirmation(
      title: 'Clear All History',
      message:
          'Are you sure you want to permanently delete all activity history?',
      subtitle: 'This action cannot be undone.',
      confirmLabel: 'Clear All',
      cancelLabel: 'Cancel',
      onConfirm: () async {
        await SoundService.to.playClick();
        await _ctrl.clearAllHistory();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      currentRoute: AppRoutes.history,
      content: TabletConstrained(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RSizedBox(h: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity History',
                style: TextStyle(
                  fontSize: context.r.sp(24),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Obx(() {
                if (_ctrl.allActivities.isEmpty) return const SizedBox.shrink();
                return Semantics(
                  label: 'Clear all history',
                  button: true,
                  child: GestureDetector(
                    onTap: _clearAllHistory,
                    child: Container(
                      padding: context.r.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[50]?.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red[100]!, width: 1),
                      ),
                      child: Icon(Icons.delete_outline,
                          color: Colors.red[700], size: context.r.scale(22)),
                    ),
                  ),
                );
              }),
            ],
          ),
          RSizedBox(h: 24),
          Expanded(
            child: Obx(() {
              if (_ctrl.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF5A3E54)),
                  ),
                );
              }

              if (_ctrl.groupedActivities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: context.r.scale(72), color: Colors.grey[300]),
                      RSizedBox(h: 20),
                      Text(
                        'No activity history yet',
                        style: TextStyle(
                          fontSize: context.r.sp(18),
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      RSizedBox(h: 8),
                      Text(
                        'Your activities will appear here',
                        style: TextStyle(fontSize: context.r.sp(14), color: Colors.grey[500]),
                      ),
                      RSizedBox(h: 4),
                      Text(
                        'Start using the app to see your history',
                        style: TextStyle(fontSize: context.r.sp(13), color: Colors.grey[400]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(bottom: context.r.scale(20)),
                itemCount: _ctrl.groupedActivities.length,
                itemBuilder: (context, index) {
                  final group = _ctrl.groupedActivities[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: context.r.scale(8), bottom: context.r.scale(12)),
                        child: Text(
                          group.period,
                          style: TextStyle(
                            fontSize: context.r.sp(14),
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5A3E54),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      for (final activity in group.activities)
                        HistoryCard(
                          key: ValueKey(activity.id),
                          activity: activity,
                          onDelete: () => _deleteActivity(activity.id),
                          onTap: () {
                            _itemTapCount++;
                            // Show interstitial every 3 items tapped
                            if (_itemTapCount % 3 == 0) {
                              try {
                                final adCtrl =
                                    Get.find<InterstitialAdController>();
                                adCtrl.showAd();
                              } catch (_) {}
                            }
                            debugPrint('[History] Tapped: ${activity.title}');
                          },
                        ),
                    ],
                  );
                },
              );
            }),
          ),
        ],
      ),
      ),
    );
  }
}

