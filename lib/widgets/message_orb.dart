import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../shared/widgets/animated_orb.dart';
import '../controllers/voice_controller.dart';

/// ═══════════════════════════════════════════════════════════════
/// Message Orb Widget
/// ═══════════════════════════════════════════════════════════════
/// A small orb attached to AI messages that syncs with the primary orb
/// - Shows when message is from AI (assistant role)
/// - Syncs lip movement and eye blinking with primary orb during read-aloud
/// - Smaller size (24px) to fit in message bubble
/// - Same animations as primary orb but scaled down
/// ═══════════════════════════════════════════════════════════════

class MessageOrb extends StatelessWidget {
  final String messageId;
  final double size;

  const MessageOrb({
    super.key,
    required this.messageId,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final vc = Get.find<VoiceController>();

      // Check if this message is currently being spoken
      final isCurrentlyPlaying =
          vc.currentSpeakingMessageId.value == messageId && vc.isTalking.value;

      return AnimatedOrb(
        size: size,
        isTalking: isCurrentlyPlaying, // Sync with primary orb
        showTalkingAnimation: true,
        autoBlink: true,
        showShadow: false, // No shadow for small message orbs
      );
    });
  }
}
