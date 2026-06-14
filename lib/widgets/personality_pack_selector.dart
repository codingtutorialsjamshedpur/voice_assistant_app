// lib/widgets/personality_pack_selector.dart
// Phase 2 - Personality Pack Selector
// Bottom sheet for selecting AI personality

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../shared/theme/responsive.dart';
import '../services/personality_response_engine.dart';
import '../controllers/profile_controller.dart';
import '../services/tts_service.dart';
import '../services/storage_service.dart';
import '../models/profile_model.dart';

/// Bottom sheet widget for selecting personality pack
class PersonalityPackSelector extends StatefulWidget {
  final Function(PersonalityPack)? onSelected;

  const PersonalityPackSelector({
    super.key,
    this.onSelected,
  });

  @override
  State<PersonalityPackSelector> createState() =>
      _PersonalityPackSelectorState();
}

class _PersonalityPackSelectorState extends State<PersonalityPackSelector> {
  late PersonalityPack selectedPack;
  final profileController = Get.find<ProfileController>();
  final ttsService = Get.find<TTSService>();

  @override
  void initState() {
    super.initState();
    // Get current selection from profile or default to Dost
    final profile = profileController.userProfile.value;
    selectedPack = PersonalityPack.values.firstWhere(
      (p) => p.label == profile.preferredPersonality,
      orElse: () => PersonalityPack.dost,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ────────────────────────────────────────
              Container(
                width: context.r.scale(40),
                height: context.r.scale(5),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose Your AI Companion',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              Text(
                'Select the personality that resonates with you',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                    ),
              ),
              const SizedBox(height: 24),

              // ── Personality Cards ─────────────────────────────────
              ...PersonalityPack.values.map((pack) {
                final isSelected = selectedPack == pack;
                return _buildPersonalityCard(
                  pack: pack,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() => selectedPack = pack);
                  },
                  onPlaySample: () => _playSample(pack),
                );
              }),

              const SizedBox(height: 24),

              // ── Action Buttons ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _saveSelection(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Select'),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: MediaQuery.of(context).viewInsets.bottom + 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalityCard({
    required PersonalityPack pack,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onPlaySample,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.deepPurple[600]!,
                    Colors.pink[600]!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.grey[800]!,
                    Colors.grey[700]!,
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.pink[400]! : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.pink.withAlpha(128),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  pack.emoji,
                  style: TextStyle(fontSize: context.r.sp(36)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.label,
                        style: TextStyle(
                          fontSize: context.r.sp(18),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pack.description,
                        style: TextStyle(
                          fontSize: context.r.sp(12),
                          color: Colors.grey[300],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                if (isSelected)
                    Container(
                      width: context.r.scale(24),
                      height: context.r.scale(24),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Icon(
                        Icons.check,
                        size: context.r.scale(16),
                        color: Colors.deepPurple[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Voice Sample Button
            SizedBox(
              width: double.infinity,
              height: context.r.scale(40),
              child: OutlinedButton.icon(
                onPressed: onPlaySample,
                icon: Icon(Icons.play_arrow, size: context.r.scale(16)),
                label: const Text('Listen to Sample'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.grey[600]!,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playSample(PersonalityPack pack) {
    // Play a greeting sample in the selected personality's voice
    final greeting =
        '${pack.opener} namaste! Mein ${pack.label} mode mein hoon. '
        'Aapke saath baat kar ke bahut khushi hogi!';

    ttsService.speak(greeting);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pack.label} says: $greeting'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _saveSelection() {
    try {
      // Update profile with selected personality
      final profile = profileController.userProfile.value;
      final updatedProfile = UserProfile(
        id: profile.id,
        name: profile.name,
        email: profile.email,
        mobileNumber: profile.mobileNumber,
        location: profile.location,
        fieldOfInterest: profile.fieldOfInterest,
        anticipation: profile.anticipation,
        gender: profile.gender,
        profileImage: profile.profileImage,
        isOnline: profile.isOnline,
        createdAt: profile.createdAt,
        updatedAt: DateTime.now(),
        defaultResponseLevel: profile.defaultResponseLevel,
        autoDetectLevel: profile.autoDetectLevel,
        preferredLevelKeywords: profile.preferredLevelKeywords,
        preferredLearningStyle: profile.preferredLearningStyle,
        childProfile: profile.childProfile,
        detectedRole: profile.detectedRole,
        preferredPersonality: selectedPack.label,
        enableMoodDetection: profile.enableMoodDetection,
        enableFestivalMode: profile.enableFestivalMode,
      );

      profileController.userProfile.value = updatedProfile;

      // Save to storage
      StorageService.to.write(
        StorageService.userProfile,
        updatedProfile.toJson(),
      );

      widget.onSelected?.call(selectedPack);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedPack.label} mode activated! 🎉'),
          backgroundColor: Colors.deepPurple[600],
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving personality: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
