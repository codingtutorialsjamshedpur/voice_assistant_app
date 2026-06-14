import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_auth;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/profile_model.dart';
import '../services/federation_service.dart';
import '../services/response_level_strategy_service.dart';
import '../services/storage_service.dart';
import '../services/profile_context_service.dart';
import '../services/user_profiling_engine_service.dart';
import '../services/role_detection_service.dart';
import '../services/supabase_service.dart';

class ProfileController extends GetxController {
  static ProfileController get to => Get.find();

  // Observable profile data
  final Rx<UserProfile> userProfile = UserProfile.defaultProfile().obs;
  final RxBool isEditing = false.obs;
  final RxBool isLoading = false.obs;

  // Expertise profiling
  late UserProfilingEngineService profilingEngine;
  final Rx<ExpertiseLevel> currentExpertiseLevel =
      ExpertiseLevel.intermediate.obs;
  final RxDouble profilingConfidence = 0.0.obs;
  final RxString profilingReason = ''.obs;
  final RxString trendDirection = 'stable'.obs;

  // Form controllers for editing
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController mobileController;
  late TextEditingController locationController;
  late TextEditingController fieldOfInterestController;
  late TextEditingController anticipationController;
  late TextEditingController ageController; // age in years

  @override
  void onInit() {
    super.onInit();
    _initControllers();
    loadProfile();

    // WP-SYNC: Listen to auth changes to update profile in real-time
    // This fixes the "guest user" glitch for returning users
    SupabaseService().client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user ?? SupabaseService().currentUser;
      if (user != null) {
        debugPrint(
            '🔄 [ProfileController] Auth change detected: ${user.email}');
        _syncProfileWithAuth(user);
      }
    });

    // Initial sync
    final currentUser = SupabaseService().currentUser;
    if (currentUser != null) {
      _syncProfileWithAuth(currentUser);
    }

    unawaited(Get.find<FederationService>().initializeFederation([]));
    profilingEngine = Get.find<UserProfilingEngineService>();
    currentExpertiseLevel.value = profilingEngine.currentExpertiseLevel.value;
    profilingConfidence.value = profilingEngine.profilingConfidence.value;
    profilingReason.value = profilingEngine.profilingReason.value;
    trendDirection.value = profilingEngine.trendDirection.value;
  }

  void _syncProfileWithAuth(supabase_auth.User user) {
    // If the profile is "Guest", update it with auth data immediately
    if (userProfile.value.id == '0' ||
        userProfile.value.email == 'user@example.com' ||
        userProfile.value.name == 'Guest User') {
      final String? fullName = user.userMetadata?['full_name'];
      final String? avatarUrl = user.userMetadata?['avatar_url'];

      debugPrint(
          '📝 [ProfileController] Updating Guest profile with Auth data: ${user.email}');

      userProfile.value = userProfile.value.copyWith(
        id: user.id,
        email: user.email ?? userProfile.value.email,
        name: fullName ?? userProfile.value.name,
        profileImage: avatarUrl ?? userProfile.value.profileImage,
        isOnline: true,
      );

      // Update controllers so the UI/Form reflects the new data
      _updateControllers();

      // Persist the changes to storage
      _persistProfile(userProfile.value);
    } else {
      // Just update status if already synced
      userProfile.value = userProfile.value.copyWith(isOnline: true);
      _persistProfile(userProfile.value);
    }
  }

  @override
  void onClose() {
    _disposeControllers();
    super.onClose();
  }

  void _initControllers() {
    nameController = TextEditingController();
    emailController = TextEditingController();
    mobileController = TextEditingController();
    locationController = TextEditingController();
    fieldOfInterestController = TextEditingController();
    anticipationController = TextEditingController();
    ageController = TextEditingController();
  }

  void _disposeControllers() {
    nameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    locationController.dispose();
    fieldOfInterestController.dispose();
    anticipationController.dispose();
    ageController.dispose();
  }

  // Load profile from storage
  void loadProfile() {
    isLoading.value = true;
    try {
      final storedProfile = StorageService.to.read(StorageService.userProfile);
      if (storedProfile != null) {
        userProfile.value = UserProfile.fromJson(storedProfile);
      } else {
        // Try to load from Supabase Auth if no stored profile (first time after sign in)
        final currentUser = SupabaseService().currentUser;
        if (currentUser != null) {
          _syncProfileWithAuth(currentUser);
        }
      }

      // ── Phase 2: Detect user role based on profile ──────────────────────
      _detectUserRole();

      _updateControllers();
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Detect user role from profile data
  void _detectUserRole() {
    try {
      if (Get.isRegistered<RoleDetectionService>()) {
        final roleService = Get.find<RoleDetectionService>();
        final profile = userProfile.value;

        final analysis = roleService.detectRole(profile);

        debugPrint(
            '🎯 Detected Role: ${analysis.role.label} (${analysis.confidence.toStringAsFixed(2)}% confidence)');
        debugPrint('   Indicators: ${analysis.indicators.join(", ")}');
      }
    } catch (e) {
      debugPrint('Error detecting user role: $e');
    }
  }

  // Update user expertise profile based on query
  Future<void> updateUserProfile(String newQuery) async {
    try {
      final enrichedProfile = await profilingEngine.profileUser(
        newQuery,
        profilingEngine.recentQueries.toList(),
      );

      currentExpertiseLevel.value = enrichedProfile.currentLevel.level;
      profilingConfidence.value = enrichedProfile.currentLevel.confidence;
      profilingReason.value = enrichedProfile.currentLevel.reason;
      trendDirection.value = enrichedProfile.trendDirection;

      debugPrint(
          'Profile updated: ${enrichedProfile.currentLevel.level} (${(enrichedProfile.currentLevel.confidence * 100).toStringAsFixed(0)}%)');
    } catch (e) {
      debugPrint('Profiling error: $e');
    }
  }

  // Get expertise level for system prompt
  String getExpertiseLevelString() {
    return profilingEngine.getLevelName(currentExpertiseLevel.value);
  }

  // Convenience getter for current expertise level name
  String get currentExpertiseLevelName => getExpertiseLevelString();

  // ── Task 1.4 + Task 3.5: ChildProfile accessors ─────────────────────

  /// Current child profile (null for adult users).
  ChildProfile? get childProfile => userProfile.value.childProfile;

  /// Returns true when detected grade level ≤ 10.
  bool get isChildUser {
    final cp = childProfile;
    if (cp == null) return false;
    return cp.detectedGradeLevel <= 10;
  }

  /// Update child context after a query (Task 3.5).
  /// Sub-services (GradeLevelDetector, LearningStyleDetector, etc.) will
  /// be injected in the ChildContextService phase (Task 3).
  void updateChildContext(String query) {
    debugPrint(
        '🧩 [ProfileController] updateChildContext: ${query.length > 40 ? '${query.substring(0, 40)}...' : query}');
    // Full implementation wired in Task 3 when ChildContextService is registered.
  }

  // Get response strategy based on detected level
  String getResponseStrategyInstructions() {
    final level = currentExpertiseLevel.value;

    if (level == ExpertiseLevel.beginner) {
      return '''
You are explaining to a beginner who is new to this topic.
- Use simple, everyday words (no jargon)
- If you must use technical term, explain it immediately
- Use ONE relatable analogy (e.g., "Think of it like...")
- Give 1-2 concrete, real-world examples
- Structure: Simple definition → 1 analogy → 1-2 examples → encouragement
- Avoid: Multiple technical terms, edge cases, abstract concepts
- Add: A gentle question at the end to encourage curiosity
''';
    } else if (level == ExpertiseLevel.intermediate) {
      return '''
You are explaining to someone with intermediate understanding.
- Use clear language but technical terms are OK (define uncommon ones)
- Provide structured explanation: Definition → mechanism → examples → application
- Give 2 relevant examples (one simple, one more complex)
- Structure: What it is → How it works → Why it matters → Examples
- You can use some technical language, but explain unfamiliar terms
- Add insight: "This concept connects to..."
- End with: "Would you like to explore [related topic]?"
''';
    } else {
      return '''
You are explaining to an expert or advanced learner.
- Skip basic definitions; focus on mechanism, nuance, and advanced concepts
- Use appropriate technical jargon and terminology
- Include edge cases, special conditions, and limitations
- Mention research frontiers or open questions if relevant
- Structure: Direct answer → mechanism/proof → edge cases → implications
- If applicable, mention citations or references
- End with: "The frontier here is..." or "Current research explores..."
- Assume reader can understand code examples and mathematical notation
''';
    }
  }

  // Should ask user for confirmation if confidence is low
  bool get shouldAskForConfirmation => profilingConfidence.value < 0.70;

  // Update form controllers with current profile data
  void _updateControllers() {
    nameController.text = userProfile.value.name;
    emailController.text = userProfile.value.email;
    mobileController.text = userProfile.value.mobileNumber;
    locationController.text = userProfile.value.location;
    fieldOfInterestController.text = userProfile.value.fieldOfInterest;
    anticipationController.text = userProfile.value.anticipation;
    ageController.text =
        userProfile.value.age > 0 ? userProfile.value.age.toString() : '';
  }

  // Save profile to storage
  Future<void> saveProfile() async {
    isLoading.value = true;
    try {
      final updatedProfile = userProfile.value.copyWith(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        mobileNumber: mobileController.text.trim(),
        location: locationController.text.trim(),
        fieldOfInterest: fieldOfInterestController.text.trim(),
        anticipation: anticipationController.text.trim(),
        age: int.tryParse(ageController.text.trim()) ?? userProfile.value.age,
      );

      await StorageService.to.setUserProfile(updatedProfile.toJson());
      // MARK AS RETURNING USER: Set isFirstTimeUser to false after profile completion
      await StorageService.to.setFirstTime(false);
      userProfile.value = updatedProfile;
      isEditing.value = false;
    } catch (e) {
      debugPrint('Error saving profile: $e');
      Get.snackbar(
        'Error',
        'Failed to save profile. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Toggle edit mode
  void toggleEditMode() {
    if (isEditing.value) {
      // Cancel edit - reset controllers
      _updateControllers();
    }
    isEditing.value = !isEditing.value;
  }

  // Persist current profile to storage (background/sync operations)
  Future<void> _persistProfile(UserProfile profile) async {
    try {
      await StorageService.to.setUserProfile(profile.toJson());
      // MARK AS RETURNING USER: Set isFirstTimeUser to false
      await StorageService.to.setFirstTime(false);
    } catch (e) {
      debugPrint('Error persisting profile: $e');
    }
  }

  // Update gender
  void updateGender(String gender) {
    // When manually selecting gender, we clear profileImage to use gender-based assets
    userProfile.value = userProfile.value.copyWith(
      gender: gender,
      profileImage: '', // Clear to fallback to assets/images/(male/female).jpg
    );
    // Sync with controllers too if email/name was updated
    _updateControllers();
    saveProfile();
  }

  // Update online status
  void updateOnlineStatus(bool isOnline) {
    userProfile.value = userProfile.value.copyWith(isOnline: isOnline);
    saveProfile();
  }

  // Get anticipation for AI context
  String getAIContext() {
    final profile = userProfile.value;
    final buffer = StringBuffer();

    buffer.writeln('User Profile Context:');
    buffer.writeln('Name: ${profile.name}');
    buffer.writeln('Location: ${profile.location}');
    buffer.writeln('Interests: ${profile.fieldOfInterest}');
    buffer.writeln('');
    buffer.writeln('User Anticipations/Expectations:');
    buffer.writeln(profile.anticipation);

    return buffer.toString();
  }

  // Validate form fields
  bool validateForm() {
    if (nameController.text.trim().isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Name is required',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange[100],
        colorText: Colors.orange[900],
      );
      return false;
    }

    if (emailController.text.trim().isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Email is required',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange[100],
        colorText: Colors.orange[900],
      );
      return false;
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(emailController.text.trim())) {
      Get.snackbar(
        'Validation Error',
        'Please enter a valid email address',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange[100],
        colorText: Colors.orange[900],
      );
      return false;
    }

    return true;
  }

  // Clear profile data (for logout)
  Future<void> clearProfile() async {
    await StorageService.to.remove(StorageService.userProfile);
    await StorageService.to.setLoggedIn(false);
    userProfile.value = UserProfile.defaultProfile();
  }

  String getProfileContextForAI() {
    try {
      return ProfileContextService.buildPrerequisiteContext(userProfile.value);
    } catch (e) {
      debugPrint('Error building profile context: $e');
      return '';
    }
  }

  String getPersonalizationDirectives() {
    try {
      return ProfileContextService.buildPersonalizationInstructions(
        userProfile.value,
      );
    } catch (e) {
      debugPrint('Error building personalization directives: $e');
      return '';
    }
  }

  bool validateProfileForAI() {
    final profile = userProfile.value;

    if (profile.name.isEmpty) {
      Get.snackbar(
        'Incomplete Profile',
        'Please set your name in profile settings.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return false;
    }

    if (profile.fieldOfInterest.isEmpty) {
      Get.snackbar(
        'Incomplete Profile',
        'Please set your field of interest for better AI personalization.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return false;
    }

    if (profile.anticipation.isEmpty) {
      Get.snackbar(
        'Incomplete Profile',
        'Please set your explanation style preference.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return false;
    }

    return true;
  }

  String buildSystemPromptWithContext(String baseSystemPrompt) {
    try {
      return ProfileContextService.buildSystemPromptWithContext(
        userProfile.value,
        baseSystemPrompt,
      );
    } catch (e) {
      debugPrint('Error building system prompt: $e');
      return baseSystemPrompt;
    }
  }

  String getContextSummary() {
    return ProfileContextService.getContextSummary(userProfile.value);
  }

  bool get hasCompleteProfile {
    final profile = userProfile.value;
    return profile.name.isNotEmpty &&
        profile.fieldOfInterest.isNotEmpty &&
        profile.anticipation.isNotEmpty;
  }
}
