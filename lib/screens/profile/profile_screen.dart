import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../services/storage_service.dart';
import '../../shared/widgets/glassmorphic_dialog.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import '../../shared/theme/dark_mode_scrim.dart';
import '../../controllers/interstitial_ad_controller.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../controllers/profile_controller.dart';
import '../../utils/string_extensions.dart';
import '../../shared/widgets/app_back_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileController());

    return AppBackground(
      child: Obx(() {
        Widget content;
        if (controller.isEditing.value) {
          content = SafeArea(
            child: _buildEditProfileView(context, controller),
          );
        } else {
          content = SafeArea(
            child: _buildProfileView(context, controller),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.r.wp(100) >= 600
                  ? context.r.scale(720)
                  : double.infinity,
            ),
            child: content,
          ),
        );
      }),
    );
  }

  // STATE 1: PROFILE VIEW
  Widget _buildProfileView(BuildContext context, ProfileController controller) {
    return Obx(() {
      final profile = controller.userProfile.value;

      return SingleChildScrollView(
        padding: context.r.all(24),
        child: Column(
          children: [
            // Profile Picture with Gender-based Image
            Stack(
              alignment: Alignment.center,
              children: [
                Hero(
                  tag: 'profile_avatar',
                  child: Container(
                    width: context.r.scale(112),
                    height: context.r.scale(112),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB2EE).withValues(alpha: 0.4),
                          blurRadius: 60,
                          spreadRadius: 30,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildProfileImage(profile.getProfileImagePath(),
                          size: context.r.scale(56)),
                    ),
                  ),
                ),
                // Edit Button Badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Semantics(
                    label: 'Edit profile',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        controller.toggleEditMode();
                      },
                      child: Container(
                        width: context.r.scale(32),
                        height: context.r.scale(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB2EE),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB2EE)
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.edit,
                          size: context.r.scale(16),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            RSizedBox(h: 16),
            // User Name
            TextWithScrim(
              child: Builder(
                builder: (ctx) => Text(
                  profile.name.toTitleCase(),
                  style: TextStyle(
                    fontSize: ctx.r.sp(28),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(ctx),
                  ),
                ),
              ),
            ),
            RSizedBox(h: 8),
            // Email Pill
            Container(
              padding: context.r.symmetric(h: 16, v: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                profile.email,
                style: TextStyle(
                  fontSize: context.r.sp(14),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF5A3E54),
                ),
              ),
            ),
            RSizedBox(h: 16),
            // Status Badge
            Container(
              padding:EdgeInsets.symmetric(horizontal: context.r.scale(16), vertical: context.r.scale(8)),
              decoration: BoxDecoration(
                color: profile.isOnline
                    ? Colors.green[100]!.withValues(alpha: 0.4)
                    : Colors.grey[100]!.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: profile.isOnline
                      ? Colors.green[200]!.withValues(alpha: 0.3)
                      : Colors.grey[200]!.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: profile.isOnline
                          ? Colors.green[500]
                          : Colors.grey[500],
                      shape: BoxShape.circle,
                    ),
                  ),
                  RSizedBox(w: 8),
                  Text(
                    profile.isOnline ? 'AI Active' : 'AI Away',
                    style: TextStyle(
                      fontSize: context.r.sp(14),
                      fontWeight: FontWeight.w500,
                      color: profile.isOnline
                          ? Colors.green[700]
                          : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            RSizedBox(h: 32),
            // Profile Actions Menu
            GlassContainer(
              padding: context.r.all(16),
              child: Column(
                children: [
                  _buildActionButton(
                    icon: Icons.edit,
                    title: 'Edit Profile',
                    subtitle: 'Update your information',
                    color: const Color(0xFFFFB2EE),
                    bgColor: const Color(0x20FFB2EE),
                    onTap: () {
                      controller.toggleEditMode();
                    },
                  ),
                  RSizedBox(h: 12),
                  _buildActionButton(
                    icon: Icons.shield_outlined,
                    title: 'Privacy',
                    subtitle: 'Manage your privacy settings',
                    color: Colors.blue[600]!,
                    bgColor: Colors.blue[100]!.withValues(alpha: 0.5),
                    onTap: () {
                      Get.toNamed(AppRoutes.privacy);
                    },
                  ),
                  RSizedBox(h: 12),
                  _buildActionButton(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    color: const Color(0xFFE53935),
                    bgColor: const Color(0x20E53935),
                    onTap: () => _showLogoutDialog(controller),
                    showArrow: false,
                  ),
                ],
              ),
            ),
            RSizedBox(h: 8),
            RSizedBox(h: 24),
            // Continue to Voice Chat Button
            Semantics(
              label: 'Continue to voice chat',
              button: true,
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  if (!controller.hasCompleteProfile) {
                    Get.snackbar(
                      'Profile Incomplete',
                      'Please edit your profile and fill in Name, Field of Interest, and Anticipation before continuing.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.orange[100],
                      colorText: Colors.orange[900],
                      duration: const Duration(seconds: 4),
                    );
                    return;
                  }
                  await controller.saveProfile();
                  await StorageService.to.setFirstTime(false);
                  try {
                    final interstitialCtrl =
                        Get.find<InterstitialAdController>();
                    interstitialCtrl.showAd();
                  } catch (_) {}
                  Get.offAllNamed(AppRoutes.voiceChat);
                },
                child: Container(
                  width: double.infinity,
                  height: context.r.buttonHeight,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFB2EE),
                        Color(0xFFFF69B4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB2EE).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Continue to Voice Chat',
                      style: TextStyle(
                        fontSize: context.r.sp(18),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            RSizedBox(h: 24),
            // Banner Ad placed at the equivalent bottom area
            const Center(child: BannerAdWidget()),
          ],
        ),
      );
    });
  }

  // STATE 2: EDIT PROFILE VIEW
  Widget _buildEditProfileView(BuildContext context, ProfileController controller) {
    final interests = [
      'Technology',
      'Science',
      'Spirituality',
      'Health & Fitness',
      'Education',
      'Business',
      'Arts & Culture',
      'Entertainment',
      'Languages',
      'Music',
      'Sports',
      'Nature & Environment',
    ];
    final learningStyles = [
      'Step-by-step guides',
      'Stories & analogies',
      'Direct answers',
      'Guided questions',
      'Detailed explanations',
    ];

    return Obx(() {
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(context.r.scale(24), context.r.scale(24), context.r.scale(24), context.r.scale(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Back Button
                  Row(
                    children: [
                      AppBackButton(
                          onPressed: () => controller.toggleEditMode()),
                      RSizedBox(w: 16),
                      TextWithScrim(
                        child: Builder(
                          builder: (ctx) => Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: ctx.r.sp(24),
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(ctx),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  RSizedBox(h: 24),
                  // Profile Picture with camera overlay
                  Center(
                    child: Stack(
                      children: [
                        Hero(
                          tag: 'profile_avatar',
                          child: Container(
                            width: context.r.scale(100),
                            height: context.r.scale(100),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFB2EE)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _buildProfileImage(
                                  controller.userProfile.value
                                      .getProfileImagePath(),
                                  size: context.r.scale(48)),
                            ),
                          ),
                        ),
                        // Camera icon overlay
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: context.r.scale(32),
                            height: context.r.scale(32),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB2EE),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: context.r.scale(16),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  RSizedBox(h: 16),
                  // Gender Selection
                  Builder(
                    builder: (ctx) => Text(
                      'Select Gender',
                      style: TextStyle(
                        fontSize: ctx.r.sp(14),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5A3E54),
                      ),
                    ),
                  ),
                  RSizedBox(h: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGenderOption(
                        context: context,
                        label: 'Male',
                        icon: Icons.male,
                        isSelected:
                            controller.userProfile.value.gender == 'male',
                        onTap: () => controller.updateGender('male'),
                      ),
                      RSizedBox(w: 16),
                      _buildGenderOption(
                        context: context,
                        label: 'Female',
                        icon: Icons.female,
                        isSelected:
                            controller.userProfile.value.gender == 'female',
                        onTap: () => controller.updateGender('female'),
                      ),
                    ],
                  ),
                  RSizedBox(h: 24),
                  // Form Fields
                  GlassContainer(
                    padding: context.r.all(20),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: controller.nameController,
                          label: 'Name',
                          hint: 'Enter your name',
                          icon: Icons.person_outline,
                        ),
                        RSizedBox(h: 16),
                        _buildTextField(
                          controller: controller.mobileController,
                          label: 'Mobile Number',
                          hint: 'Enter your mobile number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        RSizedBox(h: 16),
                        // Email - read only
                        _buildReadOnlyEmailField(controller),
                        RSizedBox(h: 16),
                        // Age field
                        Obx(() {
                          final age =
                              int.tryParse(controller.ageController.text) ??
                                  controller.userProfile.value.age;
                          final classLevel = controller.userProfile.value
                              .copyWith(age: age)
                              .estimatedClassLevel;
                          return _buildTextField(
                            controller: controller.ageController,
                            label: 'Age',
                            hint: 'Enter your age (e.g. 12)',
                            icon: Icons.cake_outlined,
                            keyboardType: TextInputType.number,
                            helperText: classLevel.isNotEmpty
                                ? '🎓 Estimated: $classLevel'
                                : 'Helps the AI explain things at your level',
                          );
                        }),
                        RSizedBox(h: 16),
                        _buildTextField(
                          controller: controller.locationController,
                          label: 'Location',
                          hint: 'Enter your location',
                          icon: Icons.location_on_outlined,
                        ),
                        RSizedBox(h: 16),
                        // Field of Interest - inline chips
                        _buildInterestsSection(controller, interests),
                        RSizedBox(h: 16),
                        // Learning Style - radio chips
                        _buildLearningStyleSection(controller, learningStyles),
                      ],
                    ),
                  ),
                  RSizedBox(h: 24),
                ],
              ),
            ),
          ),
          // Sticky Save + Cancel buttons
          Container(
            padding: EdgeInsets.fromLTRB(
              context.r.scale(24),
              context.r.scale(8),
              context.r.scale(24),
              context.r.scale(16) + MediaQuery.of(Get.context!).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withAlpha(30),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'Save profile',
                  button: true,
                  child: GestureDetector(
                    onTap: controller.isLoading.value
                        ? null
                        : () async {
                            if (controller.validateForm()) {
                              await controller.saveProfile();
                              Get.snackbar(
                                'Success',
                                'Profile updated successfully!',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.green[100],
                                colorText: Colors.green[900],
                              );
                              try {
                                final interstitialCtrl =
                                    Get.find<InterstitialAdController>();
                                interstitialCtrl.showAd();
                              } catch (_) {}
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      height: context.r.scale(52),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFB2EE),
                            Color(0xFFFF69B4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFFB2EE).withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: controller.isLoading.value
                            ? SizedBox(
                                width: context.r.scale(24),
                                height: context.r.scale(24),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                'Save Profile',
                                style: TextStyle(
                                  fontSize: context.r.sp(18),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                RSizedBox(h: 8),
                Semantics(
                  label: 'Cancel',
                  button: true,
                  child: GestureDetector(
                    onTap: () => controller.toggleEditMode(),
                    child: Container(
                      width: double.infinity,
                      height: context.r.scale(52),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: context.r.sp(16),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5A3E54),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildReadOnlyEmailField(ProfileController controller) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email ID',
            style: TextStyle(
              fontSize: context.r.sp(14),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          RSizedBox(h: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withAlpha(60),
              ),
            ),
            child: TextField(
              controller: controller.emailController,
              enabled: false,
              style: TextStyle(
                fontSize: context.r.sp(15),
                color: AppColors.textSecondary(context),
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline,
                    size: context.r.scale(20), color: Colors.grey),
                hintText: 'Email from Google Sign-In',
                hintStyle: TextStyle(
                  fontSize: context.r.sp(14),
                  color: AppColors.textTertiary(context),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: context.r.scale(16),
                  vertical: context.r.scale(14),
                ),
                border: InputBorder.none,
                helperText: 'Verified from Google account (read-only)',
                helperStyle: TextStyle(
                  fontSize: context.r.sp(11),
                  color: AppColors.textTertiary(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection(
      ProfileController controller, List<String> interests) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Field of Interest',
            style: TextStyle(
              fontSize: context.r.sp(14),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          RSizedBox(h: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.fieldOfInterestController,
            builder: (context, value, child) {
              final currentInterests = value.text
                  .split(',')
                  .map((e) => e.trim().toLowerCase())
                  .where((e) => e.isNotEmpty)
                  .toList();

              return Wrap(
                spacing: context.r.scale(8),
                runSpacing: context.r.scale(8),
                children: interests.map((interest) {
                  final isSelected =
                      currentInterests.contains(interest.toLowerCase());
                  return GestureDetector(
                    onTap: () {
                      final existing =
                          controller.fieldOfInterestController.text;
                      final interestsList = existing
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      if (!isSelected) {
                        interestsList.add(interest);
                      } else {
                        interestsList.removeWhere(
                          (e) => e.toLowerCase() == interest.toLowerCase(),
                        );
                      }
                      controller.fieldOfInterestController.text =
                          interestsList.join(', ');
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                          horizontal: context.r.scale(14), vertical: context.r.scale(8)),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF69B4).withAlpha(150)
                            : Colors.white.withAlpha(150),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF69B4)
                              : Colors.white.withAlpha(60),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF69B4).withAlpha(60),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            Padding(
                              padding: EdgeInsets.only(right: context.r.scale(6)),
                              child: Icon(
                                Icons.check_circle,
                                size: context.r.scale(16),
                                color: Colors.white,
                              ),
                            ),
                          Text(
                            interest,
                            style: TextStyle(
                              fontSize: context.r.sp(12),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLearningStyleSection(
      ProfileController controller, List<String> styles) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How I Learn Best',
            style: TextStyle(
              fontSize: context.r.sp(14),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          RSizedBox(h: 4),
          Text(
            'This helps the AI understand your needs and preferences',
            style: TextStyle(
              fontSize: context.r.sp(11),
              color: AppColors.textTertiary(context),
            ),
          ),
          RSizedBox(h: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.anticipationController,
            builder: (context, value, child) {
              final currentStyle = value.text;
              return Wrap(
                spacing: context.r.scale(8),
                runSpacing: context.r.scale(8),
                children: styles.map((style) {
                  final isSelected =
                      currentStyle.toLowerCase() == style.toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      controller.anticipationController.text =
                          isSelected ? '' : style;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                          horizontal: context.r.scale(14), vertical: context.r.scale(8)),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF69B4).withAlpha(150)
                            : Colors.white.withAlpha(150),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF69B4)
                              : Colors.white.withAlpha(60),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF69B4).withAlpha(60),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            Padding(
                              padding: EdgeInsets.only(right: context.r.scale(6)),
                              child: Icon(
                                Icons.check_circle,
                                size: context.r.scale(16),
                                color: Colors.white,
                              ),
                            ),
                          Text(
                            style,
                            style: TextStyle(
                              fontSize: context.r.sp(12),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: Builder(
        builder: (context) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: context.r.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: context.r.scale(40),
                  height: context.r.scale(40),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color),
                ),
                RSizedBox(w: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: context.r.sp(16),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: context.r.sp(12),
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showArrow)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: context.r.scale(16),
                    color: Colors.grey[400],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: () {
          onTap();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: context.r.scale(24), vertical: context.r.scale(12)),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFB2EE).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFB2EE)
                  : Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? const Color(0xFFFF69B4)
                    : const Color(0xFF5A3E54),
                size: context.r.scale(20),
              ),
              RSizedBox(w: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: context.r.sp(14),
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFFFF69B4)
                      : const Color(0xFF5A3E54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? helperText,
  }) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: context.r.sp(14),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          RSizedBox(h: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: TextStyle(
                fontSize: context.r.sp(15),
                color: AppColors.textPrimary(context),
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(icon,
                    color: AppColors.textSecondary(context), size: context.r.scale(20)),
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: context.r.sp(14),
                  color: AppColors.textTertiary(context),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: context.r.scale(16),
                  vertical: context.r.scale(14),
                ),
                border: InputBorder.none,
                helperText: helperText,
                helperStyle: TextStyle(
                  fontSize: context.r.sp(12),
                  color: AppColors.textTertiary(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String imagePath, {required double size}) {
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultIcon(size);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        },
      );
    } else if (imagePath.isNotEmpty) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultIcon(size);
        },
      );
    } else {
      return _buildDefaultIcon(size);
    }
  }

  Widget _buildDefaultIcon(double size) {
    return Container(
      color: const Color(0xFFFFB2EE).withValues(alpha: 0.3),
      child: Icon(
        Icons.person,
        size: size,
        color: Colors.white,
      ),
    );
  }

  void _showLogoutDialog(ProfileController controller) {
    GlassmorphicDialogHelper.showConfirmation(
      title: 'Logout',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Logout',
      cancelLabel: 'Cancel',
      onConfirm: () {
        controller.clearProfile();
        Get.offAllNamed(AppRoutes.authentication);
      },
    );
  }
}
