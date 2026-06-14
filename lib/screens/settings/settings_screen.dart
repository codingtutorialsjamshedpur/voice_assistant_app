import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../controllers/settings_controller.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import '../../widgets/banner_ad_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();

    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: context.r.scale(24)),
                child: TabletConstrained(
                  child: Column(
                      children: [
                    RSizedBox(h: 16),

                    // SECTION: ACCOUNT & PROFILE
                    _buildSectionHeader(context, 'Account'),
                    _buildLinkTile(
                      context,
                      icon: Icons.person_outline,
                      title: 'My Profile',
                      subtitle: 'Manage your account and preferences',
                      onTap: () => Get.toNamed(AppRoutes.profile),
                    ),
                    RSizedBox(h: 16),

                    // Banner Ad
                    const Center(child: BannerAdWidget()),
                    RSizedBox(h: 16),

                    // SECTION: AUDIO & AI BEHAVIOR
                    _buildSectionHeader(context, 'Audio & AI Behavior'),
                    GlassContainer(
                      padding: EdgeInsets.symmetric(vertical: context.r.scale(8)),
                      child: Column(
                        children: [
                          _buildVolumeSlider(context, controller),
                          Divider(height: 1, indent: context.r.scale(64)),
                          _buildToggleTile(
                            context,
                            icon: Icons.graphic_eq,
                            title: 'Sound Effects',
                            value: controller.soundEffectsEnabled,
                            onChanged: (v) => controller.toggleSoundEffects(v),
                          ),
                          _buildToggleTile(
                            context,
                            icon: Icons.vibration,
                            title: 'Haptic Feedback',
                            value: controller.hapticFeedbackEnabled,
                            onChanged: (v) =>
                                controller.toggleHapticFeedback(v),
                          ),
                          _buildToggleTile(
                            context,
                            icon: Icons.mic_none,
                            title: 'Auto Listen',
                            value: controller.autoListenEnabled,
                            onChanged: (v) => controller.toggleAutoListen(v),
                          ),
                          _buildToggleTile(
                            context,
                            icon: Icons.record_voice_over_outlined,
                            title: 'Interrupt AI',
                            value: controller.interruptAiEnabled,
                            onChanged: (v) => controller.toggleInterruptAi(v),
                          ),
                        ],
                      ),
                    ),
                    RSizedBox(h: 16),

                    // SECTION: NOTIFICATIONS
                    _buildSectionHeader(context, 'Notifications'),
                    GlassContainer(
                      padding: EdgeInsets.symmetric(vertical: context.r.scale(8)),
                      child: Column(
                        children: [
                          _buildToggleTile(
                            context,
                            icon: Icons.notifications_none,
                            title: 'Enable Notifications',
                            value: controller.notificationsEnabled,
                            onChanged: (v) => controller.toggleNotifications(v),
                          ),
                          Obx(() => Visibility(
                                visible: controller.notificationsEnabled.value,
                                child: Column(
                                  children: [
                                    Divider(height: 1, indent: context.r.scale(64)),
                                    _buildToggleTile(
                                      context,
                                      icon: Icons.alarm,
                                      title: 'Alarms',
                                      value:
                                          controller.alarmNotificationsEnabled,
                                      onChanged: (v) => controller
                                          .toggleAlarmNotifications(v),
                                      isPaddingReduced: true,
                                    ),
                                    _buildToggleTile(
                                      context,
                                      icon: Icons.today,
                                      title: 'Reminders',
                                      value: controller
                                          .reminderNotificationsEnabled,
                                      onChanged: (v) => controller
                                          .toggleReminderNotifications(v),
                                      isPaddingReduced: true,
                                    ),
                                    _buildToggleTile(
                                      context,
                                      icon: Icons.auto_awesome,
                                      title: 'Daily Wisdom',
                                      value: controller.dailyWisdomEnabled,
                                      onChanged: (v) =>
                                          controller.toggleDailyWisdom(v),
                                      isPaddingReduced: true,
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                    RSizedBox(h: 16),

                    // SECTION: APP EXPERIENCE
                    _buildSectionHeader(context, 'App Experience'),
                    GlassContainer(
                      padding: EdgeInsets.symmetric(vertical: context.r.scale(8)),
                      child: Column(
                        children: [
                          _buildLinkTile(
                            context,
                            icon: Icons.palette_outlined,
                            title: 'Appearance & Themes',
                            subtitle: 'Wallpapers and visual effects',
                            onTap: () => Get.toNamed(AppRoutes.wallpaper),
                          ),
                          Divider(height: 1, indent: context.r.scale(64)),
                          _buildToggleTile(
                            context,
                            icon: Icons.waves,
                            title: 'Orb Animation',
                            value: controller.orbAnimationEnabled,
                            onChanged: (v) => controller.toggleOrbAnimation(v),
                          ),
                        ],
                      ),
                    ),
                    RSizedBox(h: 16),

                    // SECTION: SUPPORT & LEGAL
                    _buildSectionHeader(context, 'Support & Legal'),
                    GlassContainer(
                      padding: EdgeInsets.symmetric(vertical: context.r.scale(8)),
                      child: Column(
                        children: [
                          _buildLinkTile(
                            context,
                            icon: Icons.help_outline,
                            title: 'Help & Support',
                            onTap: () => _showHelpSupportDialog(context),
                          ),
                          _buildLinkTile(
                            context,
                            icon: Icons.info_outline,
                            title: 'About App',
                            onTap: () => Get.toNamed(AppRoutes.about),
                          ),
                          _buildLinkTile(
                            context,
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            onTap: () => Get.toNamed(AppRoutes.privacyPolicy),
                          ),
                          _buildLinkTile(
                            context,
                            icon: Icons.description_outlined,
                            title: 'Terms & Conditions',
                            onTap: () => _showTermsDialog(context),
                          ),
                        ],
                      ),
                    ),
                    RSizedBox(h: 16),

                    // SECTION: MAINTENANCE
                    _buildSectionHeader(context, 'Maintenance'),
                    GlassContainer(
                      padding: EdgeInsets.symmetric(vertical: context.r.scale(8)),
                      child: Column(
                        children: [
                          _buildActionTile(
                            context,
                            icon: Icons.delete_sweep_outlined,
                            title: 'Clear Chat History',
                            color: Colors.orange[700]!,
                            onTap: () => _showClearHistoryConfirmation(
                                context, controller),
                          ),
                          _buildActionTile(
                            context,
                            icon: Icons.restart_alt,
                            title: 'Reset All Settings',
                            color: Colors.red[700]!,
                            onTap: () =>
                                _showResetConfirmation(context, controller),
                          ),
                        ],
                      ),
                    ),
                    RSizedBox(h: 48),

                    // VERSION INFO
                    Text(
                      'Version 2.0.0',
                      style: TextStyle(
                        fontSize: context.r.sp(12),
                        color: AppColors.textTertiary(context),
                      ),
                    ),
                    RSizedBox(h: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.r.scale(24), context.r.scale(24), context.r.scale(24), context.r.scale(8)),
      child: Row(
        children: [
          Semantics(
            label: 'Go back',
            button: true,
            child: GestureDetector(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Get.offNamed(AppRoutes.voiceChat);
                }
              },
              child: Container(
                padding: context.r.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.arrow_back,
                    color: AppColors.textPrimary(context)),
              ),
            ),
          ),
          RSizedBox(w: 16),
          Text(
            'Settings',
            style: TextStyle(
              fontSize: context.r.sp(24),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(context.r.scale(4), context.r.scale(16), 0, context.r.scale(8)),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: context.r.sp(12),
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary(context).withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildVolumeSlider(
      BuildContext context, SettingsController controller) {
    return Padding(
      padding: context.r.symmetric(h: 16, v: 8),
      child: Row(
        children: [
          Container(
            padding: context.r.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB2EE).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.volume_up, size: context.r.scale(20), color: const Color(0xFFFF69B4)),
          ),
          RSizedBox(w: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Master Volume',
                  style: TextStyle(
                    fontSize: context.r.sp(15),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Obx(() => SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 10),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 18),
                        thumbColor: Colors.white,
                        overlayColor: const Color(0xFFFFB2EE).withAlpha(40),
                        activeTrackColor: const Color(0xFFFFB2EE),
                        inactiveTrackColor: const Color(0xFFFFB2EE).withAlpha(80),
                      ),
                      child: Semantics(
                        label: 'Master volume',
                        child: Slider(
                          value: controller.masterVolume.value,
                          onChanged: (v) => controller.setMasterVolume(v),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required RxBool value,
    required ValueChanged<bool> onChanged,
    bool isPaddingReduced = false,
  }) {
    return Semantics(
      label: title,
      child: Obx(() => ListTile(
            contentPadding: EdgeInsets.symmetric(
                horizontal: context.r.scale(16), vertical: isPaddingReduced ? 0 : context.r.scale(4)),
            leading: Container(
              padding: context.r.all(8),
              decoration: BoxDecoration(
                color: isPaddingReduced
                    ? Colors.transparent
                    : const Color(0xFFFFB2EE).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: context.r.scale(isPaddingReduced ? 18 : 20),
                  color: isPaddingReduced
                      ? Colors.grey[600]
                      : const Color(0xFFFF69B4)),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: context.r.sp(15),
                fontWeight: isPaddingReduced ? FontWeight.w500 : FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            trailing: Switch(
              value: value.value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFFFFB2EE),
              activeTrackColor: const Color(0xFFFFB2EE).withValues(alpha: 0.3),
            ),
          )),
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: title,
      button: true,
      hint: subtitle,
      child: GlassContainer(
        margin: EdgeInsets.only(bottom: context.r.scale(8)),
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: context.r.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB2EE).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: context.r.scale(20), color: const Color(0xFFFF69B4)),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: context.r.sp(15),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: context.r.sp(12),
                    color: AppColors.textSecondary(context),
                  ),
                )
              : null,
          trailing:
              Icon(Icons.arrow_forward_ios, size: context.r.scale(14), color: Colors.grey[400]),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: context.r.scale(22), color: color),
        title: Text(
          title,
          style: TextStyle(
            fontSize: context.r.sp(15),
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        trailing: Icon(Icons.chevron_right,
            size: context.r.scale(20), color: color.withValues(alpha: 0.5)),
      ),
    );
  }

  // --- ACTIONS & DIALOGS ---

  void _showHelpSupportDialog(BuildContext context) {
    Get.defaultDialog(
      title: 'Help & Support',
      middleText:
          'For assistance or feedback, please reach out to us at ctj.helpdesk@gmail.com',
      textConfirm: 'Copy Email',
      onConfirm: () {
        // Mock copy logic
        Get.back();
        Get.snackbar('Copied', 'Email address copied to clipboard');
      },
    );
  }

  void _showTermsDialog(BuildContext context) {
    Get.defaultDialog(
      title: 'Terms & Conditions',
      middleText:
          'By using this app, you agree to our terms of service regarding data processing and AI interaction.',
      textConfirm: 'Close',
      onConfirm: () => Get.back(),
    );
  }

  void _showClearHistoryConfirmation(
      BuildContext context, SettingsController controller) {
    Get.defaultDialog(
      title: 'Clear Chat History',
      middleText:
          'This will permanently delete all your conversation history. This action cannot be undone.',
      textConfirm: 'Clear All',
      confirmTextColor: Colors.white,
      buttonColor: Colors.orange[700],
      onConfirm: () {
        controller.clearChatHistory();
        Get.back();
        Get.snackbar('History Cleared', 'All conversations have been deleted');
      },
      textCancel: 'Cancel',
    );
  }

  void _showResetConfirmation(
      BuildContext context, SettingsController controller) {
    Get.defaultDialog(
      title: 'Reset All Settings',
      middleText: 'Restore all settings to their original factory defaults?',
      textConfirm: 'Reset Defaults',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red[700],
      onConfirm: () {
        controller.resetAllSettings();
        Get.back();
        Get.snackbar('Reset Successful', 'App settings have been restored');
      },
      textCancel: 'Cancel',
    );
  }
}
