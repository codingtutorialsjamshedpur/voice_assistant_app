import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/voice_effect_model.dart';
import '../../models/voice_recording_model.dart';
import '../../routes/app_routes.dart';
import '../../services/audio_recording_service.dart';
import '../../services/audio_playback_service.dart';
import '../../services/sound_service.dart';
import '../../services/voice_effects_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';

class VoiceStudioScreen extends StatefulWidget {
  const VoiceStudioScreen({super.key});

  @override
  State<VoiceStudioScreen> createState() => _VoiceStudioScreenState();
}

class _VoiceStudioScreenState extends State<VoiceStudioScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late PageController _categoryPageController;
  int _currentCategoryIndex = 0;

  final AudioRecordingService _recordingService =
      Get.put(AudioRecordingService());
  final AudioPlaybackService _playbackService = Get.put(AudioPlaybackService());
  final VoiceEffectsService _effectsService = Get.put(VoiceEffectsService());

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _categoryPageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _categoryPageController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recording toggle
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleRecording() async {
    HapticFeedback.mediumImpact();

    if (_recordingService.isRecording.value) {
      final recording = await _recordingService.stopRecording();
      _pulseController.stop();
      if (recording != null) {
        _showVoicePreviewSheet(recording);
      }
    } else {
      final started = await _recordingService.startRecording();
      if (started) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Voice Preview Sheet (VS-01)
  // ─────────────────────────────────────────────────────────────────────────

  void _showVoicePreviewSheet(VoiceRecording recording) {
    _effectsService.stopPreview();

    // Default preview options (from TASKS.md)
    final List<VoiceEffect?> previewOptions = [
      null, // Original
      VoiceEffect.getById('bass_boost'), // Deep
      VoiceEffect.getById('chipmunk'), // Chipmunk
      VoiceEffect.getById('cave_echo'), // Echo
      VoiceEffect.getById('ai_assistant'), // Robot
    ];

    Get.bottomSheet(
      Container(
        padding: context.r.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(context.r.scale(24))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voice Preview 👀',
                style: TextStyle(
                    fontSize: context.r.sp(22),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const RSizedBox(h: 12),
            Text(
                'Tap an effect to hear it applied to your recording in real-time.',
                style: TextStyle(color: Colors.grey[700])),
            const RSizedBox(h: 20),

            // Chips row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Obx(() {
                final currentEffect = _effectsService.previewEffect.value;
                return Row(
                  children: previewOptions.map((effect) {
                    final isSelected = currentEffect?.id == effect?.id;
                    final effectName =
                        effect == null ? 'Original' : effect.name;
                    return Semantics(
                      label: 'Preview $effectName',
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _effectsService.previewRecordingWithEffect(
                              recording, effect);
                        },
                        child: Container(
                          margin: EdgeInsets.only(right: context.r.scale(12)),
                          padding: context.r.symmetric(
                              h: 18, v: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.purple : Colors.grey[200],
                          borderRadius: BorderRadius.circular(context.r.scale(20)),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: Colors.purple.withAlpha(100),
                                      blurRadius: 8,
                                      spreadRadius: 1)
                                ]
                              : null,
                        ),
                        child: Text(
                          effectName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    );
                  }).toList(),
                );
              }),
            ),
            const RSizedBox(h: 32),

            Semantics(
              label: 'Continue to save',
              button: true,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: context.r.symmetric(v: 16, h: 0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.r.scale(16))),
                  ),
                  onPressed: () {
                    _effectsService.stopPreview();
                    Get.back();
                    final selectedEffect = _effectsService.previewEffect.value;
                    final finalRecording = selectedEffect != null
                        ? recording.copyWith(effectId: selectedEffect.id)
                        : recording.copyWith(effectId: null);
                    _showSaveDialog(finalRecording);
                  },
                  child: Text('Continue to Save',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: context.r.sp(16),
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const RSizedBox(h: 16),
          ],
        ),
      ),
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
    ).then((_) {
      _effectsService.stopPreview();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save dialog
  // ─────────────────────────────────────────────────────────────────────────

  void _showSaveDialog(VoiceRecording recording) {
    final TextEditingController titleController =
        TextEditingController(text: recording.title);

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: context.r.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: context.r.scale(48)),
              const RSizedBox(h: 16),
              Text(
                'Recording Saved! 🎉',
                style: TextStyle(
                fontSize: context.r.sp(20),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const RSizedBox(h: 8),
            Text(
              'Duration: ${recording.formattedDuration}',
              style: TextStyle(fontSize: context.r.sp(14), color: Colors.grey[600]),
              ),
              if (recording.effectId != null) ...[
                const RSizedBox(h: 8),
                _buildEffectBadge(recording.effectId!),
              ],
              const RSizedBox(h: 20),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: 'Enter recording name…',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.r.scale(12)),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    context.r.symmetric(h: 16, v: 12),
                ),
              ),
              const RSizedBox(h: 20),
              // Action buttons row
              Row(
                children: [
                  Expanded(
                    child: _dialogButton(
                      label: 'Skip',
                      color: Colors.grey[300]!,
                      textColor: Colors.grey[700]!,
                      onTap: () => Get.back(),
                    ),
                  ),
                  const RSizedBox(w: 8),
                  Expanded(
                    child: _dialogButton(
                      label: 'Save',
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                      ),
                      textColor: Colors.white,
                      onTap: () {
                        _recordingService.renameRecording(
                          recording,
                          titleController.text.isEmpty
                              ? recording.title
                              : titleController.text,
                        );
                        Get.back();
                      },
                    ),
                  ),
                ],
              ),
              const RSizedBox(h: 8),
              // Save to device button
              _saveToDeviceButton(recording),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEffectBadge(String effectId) {
    final effect = VoiceEffect.getById(effectId);
    if (effect == null) return const SizedBox.shrink();
    return Builder(
      builder: (context) => Container(
      padding: context.r.symmetric(h: 12, v: 4),
      decoration: BoxDecoration(
        color: effect.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(context.r.scale(12)),
        border: Border.all(color: effect.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(effect.icon, size: context.r.scale(14), color: effect.color),
          const RSizedBox(w: 6),
          Text(
            '${effect.name} applied ✓',
            style: TextStyle(
              fontSize: context.r.sp(12),
              fontWeight: FontWeight.w600,
              color: effect.color,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _dialogButton({
    required String label,
    Color? color,
    Gradient? gradient,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: context.r.symmetric(v: 12, h: 0),
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(context.r.scale(12)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _saveToDeviceButton(VoiceRecording recording) {
    return Semantics(
      label: 'Save to device storage',
      button: true,
      child: GestureDetector(
        onTap: () async {
          Get.back();
          await _recordingService.saveToDevice(recording);
        },
        child: Container(
        width: double.infinity,
        padding: context.r.symmetric(v: 12, h: 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          ),
          borderRadius: BorderRadius.circular(context.r.scale(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_alt, color: Colors.white, size: context.r.scale(18)),
            const RSizedBox(w: 8),
            Text(
              'Save to Device Storage',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      currentRoute: AppRoutes.voiceStudio,
      content: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
          const RSizedBox(h: 16),
                  _buildHeader(),
                  const RSizedBox(h: 24),
                  Obx(() => _recordingService.selectedEffect.value != null
                      ? _buildSelectedEffectCard()
                      : _buildSelectEffectPrompt()),
                  const RSizedBox(h: 24),
                  _buildRecordingInterface(),
                  const RSizedBox(h: 24),
                  _buildEffectCategories(),
                  const RSizedBox(h: 24),
                  _buildRecentRecordings(),
                  const RSizedBox(h: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: context.r.symmetric(h: 8, v: 0),
      child: Row(
        children: [
          Container(
            padding: context.r.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
              ),
              borderRadius: BorderRadius.circular(context.r.scale(16)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB2EE).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.graphic_eq, color: Colors.white, size: context.r.scale(28)),
          ),
          const RSizedBox(w: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Studio',
                  style: TextStyle(
                    fontSize: context.r.sp(24),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Text(
                  '${VoiceEffect.allEffects.length} Effects Available',
                  style: TextStyle(fontSize: context.r.sp(14), color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Help',
            button: true,
            child: GestureDetector(
              onTap: _showHelpDialog,
              child: Container(
                padding: context.r.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.help_outline, color: Colors.grey[600], size: context.r.scale(24)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Effect prompt / selected card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSelectEffectPrompt() {
    return GlassContainer(
      padding: context.r.all(20),
      child: Column(
        children: [
          Icon(Icons.touch_app,
              size: context.r.scale(48), color: const Color(0xFFFFB2EE).withValues(alpha: 0.8)),
          const RSizedBox(h: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) => Container(
              width: context.r.scale(i == 0 ? 20 : 8),
              height: context.r.scale(8),
              margin: EdgeInsets.symmetric(horizontal: context.r.scale(3)),
              decoration: BoxDecoration(
                color: i == 0
                    ? const Color(0xFFFF69B4)
                    : const Color(0xFFFFB2EE).withAlpha(100),
                borderRadius: BorderRadius.circular(context.r.scale(4)),
              ),
            )),
          ),
          const RSizedBox(h: 12),
          Text(
            'Step 1 of 3: Select an Effect',
            style: TextStyle(
              fontSize: context.r.sp(18),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const RSizedBox(h: 8),
          Text(
            'Choose from ${VoiceEffect.allEffects.length} voice effects below,\nthen record your voice to apply it.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: context.r.sp(14), color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedEffectCard() {
    final effect = _recordingService.selectedEffect.value!;
    return Builder(
      builder: (context) => GlassContainer(
        padding: context.r.all(20),
        backgroundColor: effect.color.withValues(alpha: 0.1),
        border: Border.all(color: effect.color.withValues(alpha: 0.5), width: 2),
        child: Row(
          children: [
            Container(
              width: context.r.scale(60),
              height: context.r.scale(60),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [effect.color, effect.color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(context.r.scale(16)),
                boxShadow: [
                  BoxShadow(
                    color: effect.color.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(effect.icon, color: Colors.white, size: context.r.scale(32)),
            ),
            const RSizedBox(w: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effect.name,
                    style: TextStyle(
                    fontSize: context.r.sp(20),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const RSizedBox(h: 4),
                Text(
                  effect.description,
                  style: TextStyle(fontSize: context.r.sp(14), color: Colors.grey[600]),
                  ),
                  const RSizedBox(h: 6),
                  Container(
                    padding:
                        context.r.symmetric(h: 8, v: 3),
                    decoration: BoxDecoration(
                      color: effect.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(context.r.scale(8)),
                    ),
                    child: Text(
                      '🎙️ Ready to record with this effect',
                      style: TextStyle(
                        fontSize: context.r.sp(11),
                        fontWeight: FontWeight.w600,
                        color: effect.color,
                      ),
                    ),
                  ),
                  if (effect.isPremium) ...[
                    const RSizedBox(h: 6),
                    Container(
                      padding: context.r.symmetric(
                          h: 8, v: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Colors.amber, Colors.orange]),
                        borderRadius: BorderRadius.circular(context.r.scale(8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: context.r.scale(12)),
                          const RSizedBox(w: 4),
                          Text(
                            'PREMIUM',
                            style: TextStyle(
                              fontSize: context.r.sp(10),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                _recordingService.clearEffect();
                SoundService.to.playClick();
              },
              child: Container(
                padding: context.r.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.grey[600], size: context.r.scale(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recording interface
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRecordingInterface() {
    return Obx(() {
      final isProcessing = _recordingService.isProcessing.value;

      if (isProcessing) {
        return GlassContainer(
          padding: context.r.all(40),
          child: Column(
            children: [
              SizedBox(
                width: context.r.scale(60),
                height: context.r.scale(60),
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _recordingService.selectedEffect.value?.color ??
                        const Color(0xFFFFB2EE),
                  ),
                ),
              ),
              const RSizedBox(h: 20),
              Text(
                'Applying Effect…',
                style: TextStyle(
                  fontSize: context.r.sp(18),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const RSizedBox(h: 8),
              Text(
                'Processing your voice with '
                '${_recordingService.selectedEffect.value?.name ?? 'selected effect'}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: context.r.sp(14), color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }

      return Obx(() {
        final isRecording = _recordingService.isRecording.value;
        return Column(
          children: [
            // Big record button
            Semantics(
              label: isRecording ? 'Stop recording' : 'Start recording',
              button: true,
              child: GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale =
                        isRecording ? 1.0 + (_pulseController.value * 0.1) : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: context.r.scale(180),
                        height: context.r.scale(180),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              isRecording
                                  ? const Color(0xFFFF4444)
                                  : (_recordingService
                                          .selectedEffect.value?.color ??
                                      const Color(0xFFFFB2EE)),
                              isRecording
                                  ? const Color(0x88FF4444)
                                  : (_recordingService
                                              .selectedEffect.value?.color ??
                                          const Color(0xFFFFB2EE))
                                      .withValues(alpha: 0.5),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isRecording
                                      ? const Color(0xFFFF4444)
                                      : (_recordingService
                                              .selectedEffect.value?.color ??
                                          const Color(0xFFFFB2EE)))
                                  .withValues(alpha: 0.5),
                              blurRadius: isRecording ? 60 : 40,
                              spreadRadius: isRecording ? 25 : 15,
                            ),
                          ],
                        ),
                        child: Icon(
                          isRecording ? Icons.stop : Icons.mic,
                          size: context.r.scale(80),
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const RSizedBox(h: 24),

            // Status & timer
            Obx(() {
              final isRec = _recordingService.isRecording.value;
              final duration = _recordingService.recordingDuration.value;
              final mm = duration.inMinutes.toString().padLeft(2, '0');
              final ss = (duration.inSeconds % 60).toString().padLeft(2, '0');
              return Column(
                children: [
                  Text(
                    isRec ? '● Recording…' : 'Tap to Record',
                    style: TextStyle(
                      fontSize: context.r.sp(22),
                      fontWeight: FontWeight.w600,
                      color: isRec
                          ? const Color(0xFFFF4444)
                          : AppColors.textPrimary(context),
                    ),
                  ),
                  if (isRec)
                    Padding(
                      padding: EdgeInsets.only(top: context.r.scale(8)),
                      child: Text(
                        '$mm:$ss',
                        style: TextStyle(
                          fontSize: context.r.sp(36),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: const Color(0xFFFF4444),
                        ),
                      ),
                    ),
                ],
              );
            }),

            // Amplitude visualizer
            if (isRecording) Obx(() => _buildAmplitudeVisualizer()),
          ],
        );
      });
    });
  }

  Widget _buildAmplitudeVisualizer() {
    return Container(
      margin: EdgeInsets.only(top: context.r.scale(20)),
      height: context.r.scale(60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(20, (index) {
          final amplitude = _recordingService.amplitude.value;
          final baseHeight = 10.0 + (index % 5) * 5;
          final animatedHeight = baseHeight + (amplitude * 40);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: EdgeInsets.symmetric(horizontal: context.r.scale(2)),
            width: context.r.scale(6),
            height: animatedHeight.clamp(5, 55),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(context.r.scale(3)),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Effect categories
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEffectCategories() {
    const categories = EffectCategory.values;

    return GlassContainer(
      padding: context.r.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Voice Effects',
                style: TextStyle(
                fontSize: context.r.sp(18),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
                ),
              ),
              Container(
                padding:
                    context.r.symmetric(h: 12, v: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                  ),
                  borderRadius: BorderRadius.circular(context.r.scale(12)),
                ),
                child: Text(
                  '${VoiceEffect.allEffects.length} FX',
                  style: TextStyle(
                    fontSize: context.r.sp(10),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const RSizedBox(h: 6),
          Text(
            'Select an effect first, then record your voice',
            style: TextStyle(fontSize: context.r.sp(13), color: Colors.grey[600]),
          ),
          const RSizedBox(h: 16),

          // Category tabs
          SizedBox(
            height: context.r.scale(40),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = index == _currentCategoryIndex;
                return Semantics(
                  label: category.displayName,
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _currentCategoryIndex = index);
                      _categoryPageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                    margin: EdgeInsets.only(right: context.r.scale(8)),
                    padding: context.r.symmetric(h: 14, v: 0),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                            )
                          : null,
                      color: isSelected ? null : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(context.r.scale(20)),
                    ),
                    child: Center(
                      child: Text(
                        category.displayName,
                        style: TextStyle(
                          fontSize: context.r.sp(12),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                ),
                );
              },
            ),
          ),

          const RSizedBox(h: 16),

          // Effects grid – scrollable, adapts to number of effects
          SizedBox(
            height: _gridHeight(categories[_currentCategoryIndex]),
            child: PageView.builder(
              controller: _categoryPageController,
              onPageChanged: (index) =>
                  setState(() => _currentCategoryIndex = index),
              itemCount: categories.length,
              itemBuilder: (context, pageIndex) {
                final category = categories[pageIndex];
                final effects = VoiceEffect.getEffectsByCategory(category);
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: context.r.scale(8),
                    mainAxisSpacing: context.r.scale(8),
                  ),
                  itemCount: effects.length,
                  itemBuilder: (context, effectIndex) =>
                      _buildEffectButton(effects[effectIndex]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Calculates the grid height based on the number of effects in a category.
  double _gridHeight(EffectCategory category) {
    final count = VoiceEffect.getEffectsByCategory(category).length;
    final rows = (count / 4).ceil();
    // Each row ≈ 90 px (icon + label) + 8 px spacing
    return (rows * 90 + (rows - 1) * 8).toDouble().clamp(90, 400);
  }

  Widget _buildEffectButton(VoiceEffect effect) {
    return Obx(() {
      final isSelected =
          _recordingService.selectedEffect.value?.id == effect.id;
      return Semantics(
        label: '${effect.name} effect${effect.isPremium ? ", premium" : ""}',
        button: true,
        child: GestureDetector(
          onTap: () => _recordingService.selectEffect(effect),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [effect.color, effect.color.withValues(alpha: 0.7)],
                  )
                : LinearGradient(
                    colors: [
                      effect.color.withValues(alpha: 0.15),
                      effect.color.withValues(alpha: 0.05),
                    ],
                  ),
            borderRadius: BorderRadius.circular(context.r.scale(12)),
            border: Border.all(
              color: isSelected ? effect.color : effect.color.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: effect.color.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    effect.icon,
                    color: isSelected ? Colors.white : effect.color,
                    size: context.r.scale(26),
                  ),
                  if (effect.isPremium)
                    Positioned(
                      top: context.r.scale(-8),
                      right: context.r.scale(-8),
                      child:
                          Icon(Icons.star, color: Colors.amber[700], size: context.r.scale(13)),
                    ),
                ],
              ),
              const RSizedBox(h: 5),
              Padding(
                padding: context.r.symmetric(h: 2, v: 0),
                child: Text(
                  effect.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.r.sp(9),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textPrimary(context),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recent recordings
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRecentRecordings() {
    return Obx(() {
      final recordings = _recordingService.recordings;

      if (recordings.isEmpty) {
        return GlassContainer(
          padding: context.r.all(24),
          child: Column(
            children: [
              Icon(Icons.library_music_outlined,
                  size: context.r.scale(48), color: Colors.grey[400]),
              const RSizedBox(h: 12),
              Text(
                'No Recordings Yet',
                style: TextStyle(
                  fontSize: context.r.sp(16),
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const RSizedBox(h: 4),
              Text(
                'Your recordings will appear here',
                style: TextStyle(fontSize: context.r.sp(13), color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }

      return GlassContainer(
      padding: context.r.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Recordings',
                  style: TextStyle(
                    fontSize: context.r.sp(18),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                if (recordings.length > 3)
                  Semantics(
                    label: 'See all recordings',
                    button: true,
                    child: GestureDetector(
                      onTap: _showAllRecordings,
                      child: Text(
                        'See All (${recordings.length})',
                        style: TextStyle(
                          fontSize: context.r.sp(13),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF69B4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
                const RSizedBox(h: 16),
            ...recordings.take(3).map((r) => _buildRecordingItem(context, r)),
          ],
        ),
      );
    });
  }

  Widget _buildRecordingItem(BuildContext context, VoiceRecording recording) {
    return Obx(() {
      final isPlaying = _playbackService.isPlaying.value &&
          _playbackService.currentRecording.value?.id == recording.id;

      return Dismissible(
        key: Key(recording.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: context.r.scale(20)),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(context.r.scale(12)),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => _recordingService.deleteRecording(recording),
        child: Container(
          margin: EdgeInsets.only(bottom: context.r.scale(12)),
          padding: context.r.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(context.r.scale(12)),
            border: isPlaying
                ? Border.all(color: const Color(0xFFFF69B4), width: 2)
                : null,
          ),
          child: Row(
            children: [
              // Play/pause button
              Semantics(
                label: isPlaying ? 'Pause' : 'Play',
                button: true,
                child: GestureDetector(
                  onTap: () => _playbackService.togglePlayPause(recording),
                  child: Container(
                    width: context.r.scale(48),
                    height: context.r.scale(48),
                    decoration: BoxDecoration(
                      gradient: isPlaying
                          ? const LinearGradient(
                              colors: [Color(0xFFFF4444), Color(0xFFFF6B6B)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                            ),
                      borderRadius: BorderRadius.circular(context.r.scale(12)),
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: context.r.scale(28),
                    ),
                  ),
                ),
              ),
                const RSizedBox(w: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.title,
                      style: TextStyle(
                      fontSize: context.r.sp(14),
                      fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const RSizedBox(h: 4),
                    Row(
                      children: [
                        Text(
                          recording.formattedDate,
                          style:
                              TextStyle(fontSize: context.r.sp(12), color: Colors.grey[600]),
                        ),
                        if (recording.effectId != null) ...[
                          const RSizedBox(w: 8),
                          _smallEffectBadge(recording.effectId!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Duration + actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    recording.formattedDuration,
                    style: TextStyle(
                      fontSize: context.r.sp(12),
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                    const RSizedBox(h: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'Share',
                        button: true,
                        child: GestureDetector(
                          onTap: () => _shareRecording(recording),
                          child: Icon(Icons.share,
                              size: 18, color: Colors.grey[500]),
                        ),
                      ),
              const RSizedBox(w: 12),
                      Semantics(
                        label: 'More options',
                        button: true,
                        child: GestureDetector(
                          onTap: () => _showRecordingOptions(recording),
                          child: Icon(Icons.more_vert,
                              size: context.r.scale(20), color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _smallEffectBadge(String effectId) {
    final effect = VoiceEffect.getById(effectId);
    if (effect == null) return const SizedBox.shrink();
    return Builder(
      builder: (context) => Container(
      padding: context.r.symmetric(h: 6, v: 2),
      decoration: BoxDecoration(
        color: effect.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(context.r.scale(6)),
      ),
      child: Text(
        effect.name,
        style: TextStyle(
          fontSize: context.r.sp(9),
          fontWeight: FontWeight.w500,
          color: effect.color,
        ),
      ),
    ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recording options bottom sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _showRecordingOptions(VoiceRecording recording) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(context.r.scale(20))),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: context.r.scale(12), bottom: context.r.scale(8)),
                width: context.r.scale(40),
                height: context.r.scale(4),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(context.r.scale(2)),
                ),
              ),
              // Recording title header
              Padding(
                padding:
                    context.r.symmetric(h: 16, v: 8),
                child: Row(
                  children: [
                    if (recording.effectId != null)
                      _smallEffectBadge(recording.effectId!),
                    const RSizedBox(w: 8),
                    Expanded(
                      child: Text(
                        recording.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: context.r.sp(16),
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Builder(
                builder: (ctx) => ListTile(
                  leading: Icon(Icons.edit, color: AppColors.textPrimary(ctx)),
                  title: const Text('Rename'),
                  onTap: () {
                    Get.back();
                    _showRenameDialog(recording);
                  },
                ),
              ),
              Builder(
                builder: (ctx) => ListTile(
                  leading: Icon(
                    recording.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: recording.isFavorite
                        ? Colors.red
                        : AppColors.textPrimary(ctx),
                  ),
                  title: Text(recording.isFavorite
                      ? 'Remove from Favorites'
                      : 'Add to Favorites'),
                  onTap: () async {
                    final message =
                        await _recordingService.toggleFavorite(recording);
                    Get.back();
                    if (message != null) {
                      Get.snackbar('Success', message,
                          backgroundColor: Colors.green,
                          colorText: Colors.white);
                    }
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.save_alt, color: Color(0xFF2E7D32)),
                title: const Text('Save to Device Storage',
                    style: TextStyle(color: Color(0xFF2E7D32))),
                subtitle: Text('Save to VoiceStudio folder',
                    style: TextStyle(fontSize: context.r.sp(12))),
                onTap: () async {
                  Get.back();
                  await _recordingService.saveToDevice(recording);
                },
              ),
              Builder(
                builder: (ctx) => ListTile(
                  leading: Icon(Icons.share, color: AppColors.textPrimary(ctx)),
                  title: const Text('Share'),
                  onTap: () {
                    Get.back();
                    _shareRecording(recording);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Get.back();
                  _recordingService.deleteRecording(recording);
                },
              ),
              const RSizedBox(h: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(VoiceRecording recording) {
    final controller = TextEditingController(text: recording.title);
    Get.dialog(
      AlertDialog(
        title: const Text('Rename Recording'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new name…'),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _recordingService.renameRecording(recording, controller.text);
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _shareRecording(VoiceRecording recording) async {
    final file = File(recording.filePath);
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(recording.filePath)],
        text: 'Check out my voice recording: ${recording.title}',
      );
    } else {
      Get.snackbar('Error', 'Recording file not found',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _showAllRecordings() {
    Get.to(() => const AllRecordingsScreen());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Help dialog
  // ─────────────────────────────────────────────────────────────────────────

  void _showHelpDialog() {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: context.r.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_outline,
                  color: const Color(0xFFFFB2EE), size: context.r.scale(48)),
              const RSizedBox(h: 16),
              Text(
                'How to Use Voice Studio',
                style: TextStyle(
                fontSize: context.r.sp(20),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const RSizedBox(h: 16),
              _buildHelpStep('1', 'Select a Voice Effect',
                  'Choose from ${VoiceEffect.allEffects.length} effects across 7 categories'),
              _buildHelpStep('2', 'Tap Record',
                  'Press the big microphone button to start recording'),
              _buildHelpStep('3', 'Effect Applied Automatically',
                  'Your voice is processed with the selected effect when you stop'),
              _buildHelpStep('4', 'Save to Device',
                  'Tap "Save to Device Storage" to keep it in your VoiceStudio folder'),
              const RSizedBox(h: 20),
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  padding: context.r.symmetric(v: 12, h: 0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                    ),
                    borderRadius: BorderRadius.circular(context.r.scale(12)),
                  ),
                  child: Center(
                    child: Text(
                      'Got it!',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpStep(String step, String title, String description) {
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: context.r.scale(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: context.r.scale(28),
              height: context.r.scale(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                ),
                borderRadius: BorderRadius.circular(context.r.scale(8)),
              ),
              child: Center(
                child: Text(
                  step,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const RSizedBox(w: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: context.r.sp(15),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: context.r.sp(13), color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All Recordings Screen
// ─────────────────────────────────────────────────────────────────────────────

class AllRecordingsScreen extends StatelessWidget {
  const AllRecordingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recordingService = Get.find<AudioRecordingService>();
    final playbackService = Get.find<AudioPlaybackService>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('All Recordings',
            style: TextStyle(color: AppColors.textPrimary(context))),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
          onPressed: () => Get.back(),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Obx(() {
            final recordings = recordingService.recordings;

            if (recordings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_music_outlined,
                        size: context.r.scale(64), color: Colors.grey[400]),
            const RSizedBox(h: 16),
                    Text('No Recordings Yet',
                        style:
                            TextStyle(fontSize: context.r.sp(18), color: Colors.grey[600])),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: context.r.all(16),
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                final recording = recordings[index];
                return _buildRecordingCard(
                    context, recording, playbackService, recordingService);
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRecordingCard(
    BuildContext context,
    VoiceRecording recording,
    AudioPlaybackService playbackService,
    AudioRecordingService recordingService,
  ) {
    return Obx(() {
      final isPlaying = playbackService.isPlaying.value &&
          playbackService.currentRecording.value?.id == recording.id;

      return Card(
        margin: EdgeInsets.only(bottom: context.r.scale(12)),
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.r.scale(16))),
        child: ListTile(
          contentPadding:
              context.r.symmetric(h: 16, v: 8),
          leading: GestureDetector(
            onTap: () => playbackService.togglePlayPause(recording),
            child: Container(
              width: context.r.scale(50),
              height: context.r.scale(50),
              decoration: BoxDecoration(
                gradient: isPlaying
                    ? const LinearGradient(
                        colors: [Color(0xFFFF4444), Color(0xFFFF6B6B)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                      ),
                borderRadius: BorderRadius.circular(context.r.scale(12)),
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: context.r.scale(28),
              ),
            ),
          ),
          title: Builder(
            builder: (context) => Text(
              recording.title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context)),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RSizedBox(h: 4),
              Text(
                '${recording.formattedDate} • ${recording.formattedDuration}',
                style: TextStyle(fontSize: context.r.sp(12), color: Colors.grey[600]),
              ),
              if (recording.effectId != null) ...[
                const RSizedBox(h: 4),
                _effectChip(recording.effectId!),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recording.isFavorite)
                Icon(Icons.favorite, color: Colors.red, size: context.r.scale(20)),
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                onPressed: () => _showOptions(context, recording, recordingService),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _effectChip(String effectId) {
    final effect = VoiceEffect.getById(effectId);
    if (effect == null) return const SizedBox.shrink();
    return Builder(
      builder: (context) => Container(
      padding: context.r.symmetric(h: 8, v: 2),
      decoration: BoxDecoration(
        color: effect.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(context.r.scale(8)),
      ),
      child: Text(
        effect.name,
        style: TextStyle(fontSize: context.r.sp(10), color: effect.color),
      ),
    ),
    );
  }

  void _showOptions(BuildContext context, VoiceRecording recording, AudioRecordingService service) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(context.r.scale(20))),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () => Get.back(),
              ),
              ListTile(
                leading: const Icon(Icons.save_alt, color: Color(0xFF2E7D32)),
                title: const Text('Save to Device Storage',
                    style: TextStyle(color: Color(0xFF2E7D32))),
                onTap: () async {
                  Get.back();
                  await service.saveToDevice(recording);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () async {
                  Get.back();
                  final file = File(recording.filePath);
                  if (await file.exists()) {
                    await Share.shareXFiles([XFile(recording.filePath)]);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Get.back();
                  service.deleteRecording(recording);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
