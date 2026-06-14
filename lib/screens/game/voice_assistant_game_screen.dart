import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/voice_assistant_game_controller.dart';
import '../../services/gesture_recognizer_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/recording_indicator.dart';
import '../../widgets/language_badge.dart';
import '../../widgets/trigger_word_hints_panel.dart';
import '../../widgets/language_picker_bottom_sheet.dart';
import 'widgets/voice_game_help_hint.dart';
import '../../services/family_relationship_manager_service.dart';
import '../../services/health_hygiene_manager_service.dart';
import '../../features/orb_thinking/orb_thinking_controller.dart';
import '../../features/orb_thinking/thought_bubble_widget.dart';
import '../../services/audio_export_service.dart';
import '../../widgets/audio_export_panel.dart';
import '../../shared/controllers/top_panel_controller.dart';

// Added for cleanup
import '../../controllers/voice_controller.dart';
import '../../services/engagement_orchestrator_service.dart';
import '../../services/enhanced_greeting_service.dart';
import '../../services/stt_service.dart';
import '../../services/tts_service.dart';
import '../../services/idle_prompt_service.dart';
import '../../services/voice_session_restoration_manager.dart';

class VoiceAssistantGameScreen extends StatefulWidget {
  const VoiceAssistantGameScreen({super.key});

  @override
  State<VoiceAssistantGameScreen> createState() =>
      _VoiceAssistantGameScreenState();
}

class _VoiceAssistantGameScreenState extends State<VoiceAssistantGameScreen>
    with TickerProviderStateMixin {
  late VoiceAssistantGameController controller;
  late FamilyRelationshipManagerService _familyManager; // ignore: unused_field
  late HealthHygieneManagerService _healthManager; // ignore: unused_field
  Worker? _saveAudioWorker;
  Worker? _transcriptScrollWorker;
  final ScrollController _transcriptScrollController = ScrollController();

  late AnimationController _glowController;
  late AnimationController _floatController;
  late AnimationController _blinkController;
  late AnimationController _mouthController;

  @override
  void initState() {
    super.initState();

    // ----- FIX 1: Complete Reset of Voice Chat AI Services Via Central Architecture -----
    unawaited(VoiceSessionRestorationManager.to.restore());

    // ── Mark game screen as active so idle-prompt TTS is suppressed ──────────
    // VoiceChatScreen idle-poke timer keeps running in the background;
    // this flag prevents it from speaking into the game screen's TTS channel.
    try {
      if (Get.isRegistered<IdlePromptService>()) {
        Get.find<IdlePromptService>().isGameScreenActive = true;
        debugPrint('🎮 [VoiceAssistantGameScreen] Idle prompt suppressed');
      }
    } catch (_) {}
    // -----------------------------------------------------------

    controller = Get.put(VoiceAssistantGameController());

    // Initialize Family Relationship Manager
    try {
      _familyManager = Get.find<FamilyRelationshipManagerService>();
    } catch (e) {
      debugPrint('⚠️ Family Manager not available in game screen: $e');
    }

    // Initialize Health & Hygiene Manager
    try {
      _healthManager = Get.find<HealthHygieneManagerService>();
    } catch (e) {
      debugPrint('⚠️ Health Manager not available in game screen: $e');
    }

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: 150), () {
            _blinkController.reverse();
          });
        }
      });

    _mouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _blinkController.forward();
      }
    });

    // Listen for completed orb responses and offer "Save Audio?"
    _saveAudioWorker = ever(controller.lastSpokenResponse, (String? text) {
      if (text == null || text.isEmpty) return;
      // Small delay so the listening loop starts before the sheet pops up
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showSaveAudioSheet(text);
      });
    });

    // Auto-scroll transcript to bottom whenever new speech text arrives
    _transcriptScrollWorker = ever(controller.currentSpeechText, (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_transcriptScrollController.hasClients) {
          _transcriptScrollController.animateTo(
            _transcriptScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _saveAudioWorker?.dispose();
    _transcriptScrollWorker?.dispose();
    _transcriptScrollController.dispose();
    _glowController.dispose();
    _floatController.dispose();
    _blinkController.dispose();
    _mouthController.dispose();

    try {
      Get.find<OrbThinkingController>().clearAvatar();
    } catch (_) {}

    // ── Release game-screen isolation so VoiceChat idle prompts resume ────
    try {
      if (Get.isRegistered<IdlePromptService>()) {
        Get.find<IdlePromptService>().isGameScreenActive = false;
        debugPrint(
            '🔄 [VoiceAssistantGameScreen] Idle prompt isolation released');
      }
    } catch (_) {}

    // ----- FIX 2: Full Game AI Cleanup on Dispose -----
    try {
      controller.onClose(); // Force stop game logic if instance is lingering
    } catch (_) {}

    try {
      final sttService = Get.find<STTService>();
      sttService.cancelListening();
    } catch (_) {}

    try {
      final ttsService = Get.find<TTSService>();
      ttsService.stop();
    } catch (_) {}
    // --------------------------------------------------

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        controller.remindExitTrigger();
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        _buildOrbWithRipples(),
                        const SizedBox(height: 32),
                        _buildStatusLabel(),
                        const SizedBox(height: 12),
                        _buildSoundWaveBar(),
                        const SizedBox(height: 16),
                        _buildTriggerHints(),
                        const Spacer(flex: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTriggerHints() {
    return Obx(() => TriggerWordHintsPanel(
          preferredLanguage: controller.preferredLanguage.value,
          onEndOfThoughtPlay: () {
            controller.speakTriggerWord('endOfThought');
          },
          onExitPlay: () {
            controller.speakTriggerWord('exit');
          },
        ));
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(() => GestureDetector(
                onTap: () => _showLanguageSelector(context),
                child: LanguageBadge(
                  currentLanguage: controller.preferredLanguage.value,
                  onTap: () => _showLanguageSelector(context),
                ),
              )),
          Obx(() => VoiceGameHelpHint(
                currentState: controller.orbState.value,
              )),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    LanguagePickerBottomSheet.show(context);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save Audio Bottom Sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _showSaveAudioSheet(String orbText) {
    final uniqueId = 'game_orb_${DateTime.now().millisecondsSinceEpoch}';
    final exportService = Get.find<AudioExportService>();

    // Grab the dynamic theme color — same source as LanguagePickerBottomSheet
    final TopPanelController topPanelCtrl = Get.find<TopPanelController>();

    Get.bottomSheet(
      Obx(() {
        final currentColor = topPanelCtrl.currentColor;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withAlpha(51),
                Colors.white.withAlpha(26),
                currentColor.withAlpha(38),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: currentColor.withAlpha(128),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: currentColor.withAlpha(77),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, -10),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(128),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Handle bar ───────────────────────────────────
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 16),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: currentColor.withAlpha(160),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ── Title row ─────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: currentColor.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: currentColor.withAlpha(100)),
                            ),
                            child: Icon(
                              Icons.save_alt_rounded,
                              color: currentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Save Orb Response',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: currentColor.withAlpha(180),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Record & share this response',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(140),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.white.withAlpha(160),
                              size: 20,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Preview text snippet ──────────────────────────
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: currentColor.withAlpha(60), width: 1),
                        ),
                        child: RawScrollbar(
                          thumbColor: currentColor.withAlpha(100),
                          radius: const Radius.circular(8),
                          thickness: 4,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              orbText,
                              style: TextStyle(
                                color: Colors.white.withAlpha(180),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Action area ───────────────────────────────────
                      Obx(() {
                        final generating =
                            exportService.isCurrentlyGenerating(uniqueId);
                        final ready = exportService.isFileReady(uniqueId);
                        final progress = exportService.getProgress(uniqueId);
                        final pct = (progress * 100).toInt();

                        if (!ready && !generating) {
                          // ── Generate CTA ────────────────────────────────
                          return GestureDetector(
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              final langCode =
                                  controller.preferredLanguage.value.sttLocale;
                              await exportService.generateAudioFile(
                                uniqueId,
                                orbText,
                                brandingScreen: 'game',
                                languageCode: langCode,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    currentColor.withAlpha(70),
                                    currentColor.withAlpha(40),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: currentColor.withAlpha(160),
                                    width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: currentColor.withAlpha(60),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download_rounded,
                                      color: currentColor, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Record & Save Audio',
                                    style: TextStyle(
                                      color: currentColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (generating) {
                          // ── Progress arc ─────────────────────────────────
                          return Column(
                            children: [
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: CircularProgressIndicator(
                                        value: 1.0,
                                        strokeWidth: 4,
                                        color: currentColor.withAlpha(45),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 4,
                                        color: currentColor,
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                    Text(
                                      '$pct%',
                                      style: TextStyle(
                                        color: currentColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                              color:
                                                  currentColor.withAlpha(160),
                                              blurRadius: 6),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                pct < 99
                                    ? 'Recording audio… $pct% done'
                                    : 'Finishing up…',
                                style: TextStyle(
                                    color: Colors.white.withAlpha(200),
                                    fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Longer responses take more time',
                                style: TextStyle(
                                    color: Colors.white.withAlpha(100),
                                    fontSize: 11),
                              ),
                            ],
                          );
                        }

                        // ── File ready ────────────────────────────────────
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: currentColor, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Audio saved!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                          color: currentColor.withAlpha(180),
                                          blurRadius: 8),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AudioExportPanel(
                              messageId: uniqueId,
                              messageText: orbText,
                              brandingScreen: 'game',
                              languageCode:
                                  controller.preferredLanguage.value.sttLocale,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                exportService.deleteAudio(uniqueId);
                                Get.back();
                              },
                              child: Text(
                                'Dismiss & delete',
                                style: TextStyle(
                                    color: Colors.white.withAlpha(100),
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        );
                      }),

                      const SizedBox(height: 4),
                      // ── Not now ───────────────────────────────────────
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text(
                          'Not now',
                          style: TextStyle(
                              color: Colors.white.withAlpha(80), fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildOrbWithRipples() {
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Obx(() => AnimatedOpacity(
                opacity:
                    controller.orbState.value == OrbState.listening ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildRippleRings(),
              )),
          Obx(() => _OrbWidget(
                controller: controller,
                glowController: _glowController,
                floatController: _floatController,
                blinkController: _blinkController,
                mouthController: _mouthController,
                isSpeaking: controller.isSpeaking.value,
              )),
          // Thought Bubble - positioned above and to the right of orb
          Positioned(
            right: -45,
            top: -45,
            child: Obx(() {
              final orbController = Get.find<OrbThinkingController>();
              return ThoughtBubbleWidget(
                avatarAssetPath: orbController.currentAvatarPath ?? '',
                visible: orbController.showCloud &&
                    orbController.currentAvatarPath != null,
                size: 65,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRippleRings() {
    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final progress = (_glowController.value + index * 0.13) % 1.0;
              final radius = 110 + progress * 70;
              final opacity = (1.0 - progress) * 0.3;
              return Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF69B4).withValues(alpha: opacity),
                    width: 2,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildStatusLabel() {
    return Obx(() {
      final state = controller.orbState.value;
      String text;
      String icon;
      // Determine whether we are in the live-transcript mode
      final bool isListeningWithTranscript = state == OrbState.listening &&
          !controller.isPaused.value &&
          controller.currentSpeechText.value.isNotEmpty;

      switch (state) {
        case OrbState.idle:
          icon = '👂';
          text = 'Tap to begin';
          break;
        case OrbState.listening:
          icon = controller.isPaused.value ? '⏸️' : '🎤';
          text =
              controller.isPaused.value ? 'Ruka hoon...' : 'Sun raha hoon...';
          break;
        case OrbState.processing:
          icon = '⏳';
          text = 'Soch raha hoon...';
          break;
        case OrbState.speaking:
          icon = '🗣️';
          text = 'Bol raha hoon...';
          break;
        case OrbState.farewell:
          icon = '👋';
          text = 'Alvida...';
          break;
      }

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        // Key only on the state label so the container does NOT rebuild
        // every time the transcript text updates — only on state transitions.
        child: Container(
          key: ValueKey(state),
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Status label row ──────────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Transcript / hint area ────────────────────────────────
              if (isListeningWithTranscript)
                // Live transcript: fixed-height, internally scrollable
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 0,
                    maxHeight: 120, // ~4-5 lines at font-size 11
                  ),
                  child: Scrollbar(
                    controller: _transcriptScrollController,
                    thumbVisibility: false,
                    child: SingleChildScrollView(
                      controller: _transcriptScrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        controller.currentSpeechText.value,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                          height: 1.55,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                // Static hint for all other states
                Text(
                  state == OrbState.idle
                      ? 'Tap orb to start · Double-tap to reset'
                      : state == OrbState.listening
                          ? (controller.isPaused.value
                              ? 'Tap to resume'
                              : controller.flippingTriggerHint.value)
                          : state == OrbState.processing
                              ? 'AI is thinking...'
                              : state == OrbState.speaking
                                  ? 'Listen to the response'
                                  : 'Thanks for playing!',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSoundWaveBar() {
    return Obx(() => AnimatedOpacity(
          opacity: controller.orbState.value == OrbState.listening ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: RecordingIndicatorAnimation(
            color: _getOrbColor(),
            cycleDuration: const Duration(milliseconds: 600),
            dotCount: 6,
          ),
        ));
  }

  Color _getOrbColor() {
    switch (controller.orbState.value) {
      case OrbState.idle:
        return const Color(0xFFFFB1EE);
      case OrbState.listening:
        return const Color(0xFFFF69B4);
      case OrbState.processing:
        return const Color(0xFF8B5CF6);
      case OrbState.speaking:
        return const Color(0xFFFFB347);
      case OrbState.farewell:
        return const Color(0xFFE0E0E0);
    }
  }
}

class _OrbWidget extends StatefulWidget {
  final VoiceAssistantGameController controller;
  final AnimationController glowController;
  final AnimationController floatController;
  final AnimationController blinkController;
  final AnimationController mouthController;
  final bool isSpeaking;

  const _OrbWidget({
    required this.controller,
    required this.glowController,
    required this.floatController,
    required this.blinkController,
    required this.mouthController,
    required this.isSpeaking,
  });

  @override
  State<_OrbWidget> createState() => _OrbWidgetState();
}

class _OrbWidgetState extends State<_OrbWidget> {
  int _tapCount = 0;
  Timer? _tapTimer;

  void _handleTap() {
    _tapCount++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 300), () {
      final taps = _tapCount;
      _tapCount = 0;

      if (taps == 1) {
        HapticFeedback.mediumImpact();
        Get.find<GestureRecognizerService>()
            .handleGesture(VoiceGestureType.singleTap);
        widget.controller.onOrbSingleTap();
      } else if (taps == 2) {
        Get.find<GestureRecognizerService>()
            .handleGesture(VoiceGestureType.doubleTap);
        widget.controller.onOrbDoubleTap();
      } else if (taps >= 3) {
        Get.find<GestureRecognizerService>().handleGesture(
            VoiceGestureType.doubleTap); // Fallback for gesture log
        Get.snackbar(
          '🔄 Hard Reset',
          'Resetting mic, memory & AI models...\nTap orb to start fresh!',
          backgroundColor: Colors.deepPurple.withValues(alpha: 0.92),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(12),
          borderRadius: 16,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        );
        widget.controller.onOrbTripleTap();
      }
    });
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onLongPress: () {
        Get.find<GestureRecognizerService>()
            .handleGesture(VoiceGestureType.longPress);
      },
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        if (velocity.distance < 100) return; // Ignore small movements

        if (velocity.dx.abs() > velocity.dy.abs()) {
          if (velocity.dx > 0) {
            Get.find<GestureRecognizerService>()
                .handleGesture(VoiceGestureType.swipeRight);
          } else {
            Get.find<GestureRecognizerService>()
                .handleGesture(VoiceGestureType.swipeLeft);
          }
        } else {
          if (velocity.dy > 0) {
            Get.find<GestureRecognizerService>()
                .handleGesture(VoiceGestureType.swipeDown);
          } else {
            Get.find<GestureRecognizerService>()
                .handleGesture(VoiceGestureType.swipeUp);
          }
        }
      },
      child: Obx(() {
        final state = widget.controller.orbState.value;

        return AnimatedBuilder(
          animation: widget.glowController,
          builder: (context, child) {
            final glowValue = widget.glowController.value;
            final baseIntensity = _getGlowIntensity(state);
            final glowIntensity = baseIntensity + (glowValue * 0.3);
            final orbColor = _getOrbColor(state);
            final offsetY = (widget.floatController.value - 0.5) * 50;

            return Transform.translate(
              offset: Offset(0, offsetY),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    radius: 0.8,
                    colors: [
                      const Color(0xFFFFFFFF).withValues(alpha: 0.9),
                      Color.lerp(const Color(0xFFFFE4F5), orbColor, 0.3)!
                          .withValues(alpha: 0.7),
                      orbColor.withValues(alpha: glowIntensity),
                      orbColor.withValues(alpha: 0.3),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: orbColor.withValues(alpha: 0.3 + glowValue * 0.3),
                      blurRadius: 30 + (glowValue * 15),
                      spreadRadius: 5 + (glowValue * 10),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 50,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.2, -0.2),
                          radius: 0.6,
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 35,
                            left: 45,
                            child: Container(
                              width: 30,
                              height: 18,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.8),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 50,
                            left: 38,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildEye(widget.blinkController),
                                  const SizedBox(width: 30),
                                  _buildEye(widget.blinkController),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildMouth(state, widget.mouthController),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildEye(AnimationController blinkController) {
    return AnimatedBuilder(
      animation: blinkController,
      builder: (context, child) {
        final scaleY = 1.0 - (blinkController.value * 0.9);
        return Transform.scale(
          scaleY: scaleY,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2D1B2E).withValues(alpha: 0.7),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMouth(OrbState state, AnimationController mouthController) {
    if (state == OrbState.idle || state == OrbState.farewell) {
      return Container(
        width: 20,
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF2D1B2E).withValues(alpha: 0.5),
        ),
      );
    }

    if (state == OrbState.listening) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2D1B2E).withValues(alpha: 0.5),
        ),
      );
    }

    if (state == OrbState.processing) {
      return Container(
        width: 25,
        height: 15,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF2D1B2E).withValues(alpha: 0.5),
        ),
      );
    }

    return AnimatedBuilder(
      animation: mouthController,
      builder: (context, child) {
        final progress = mouthController.value;
        final mouthHeight = 10 + (math.sin(progress * math.pi) * 12);
        final mouthWidth = 22 + (math.sin(progress * math.pi * 1.2) * 6);
        final borderRadius = 8 + (math.sin(progress * math.pi * 0.8) * 4);

        return Container(
          width: mouthWidth,
          height: mouthHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2D1B2E).withValues(alpha: 0.6),
                const Color(0xFFD4695A).withValues(alpha: 0.3),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getOrbColor(OrbState state) {
    switch (state) {
      case OrbState.idle:
        return const Color(0xFFFFB1EE);
      case OrbState.listening:
        return const Color(0xFFFF69B4);
      case OrbState.processing:
        return const Color(0xFF8B5CF6);
      case OrbState.speaking:
        return const Color(0xFFFFB347);
      case OrbState.farewell:
        return const Color(0xFFE0E0E0);
    }
  }

  double _getGlowIntensity(OrbState state) {
    switch (state) {
      case OrbState.idle:
        return 0.4;
      case OrbState.listening:
        return 0.6;
      case OrbState.processing:
        return 0.5;
      case OrbState.speaking:
        return 0.7;
      case OrbState.farewell:
        return 0.2;
    }
  }
}
