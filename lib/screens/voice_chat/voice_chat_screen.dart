import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../main.dart'; // For routeObserver
import '../../controllers/voice_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/language_controller.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/animated_orb.dart';
import '../../shared/widgets/glassmorphic_dialog.dart';
import '../../features/orb_thinking/orb_thinking_controller.dart';
import '../../features/orb_thinking/thought_bubble_widget.dart';
import '../../services/query_handler_service.dart';
import '../../services/idle_prompt_service.dart';
import '../../services/profile_context_service.dart';
import '../../services/engagement_orchestrator_service.dart';
import '../../services/enhanced_greeting_service.dart';
import '../../services/stt_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/tts_aware_message_body.dart';
import '../../widgets/audio_export_panel.dart';
import '../../widgets/ai_model_selector_backdrop.dart';
import '../../widgets/message_orb.dart';
import '../../services/family_relationship_manager_service.dart';
import '../../services/health_hygiene_manager_service.dart';
import '../../services/ai_model_manager.dart';
import '../../controllers/query_prediction_controller.dart';
import '../../widgets/suggestion_bubble.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import '../../services/voice_session_restoration_manager.dart';

/// ═══════════════════════════════════════════════════════════════
/// Voice Chat Screen — The main AI conversation interface
/// ═══════════════════════════════════════════════════════════════
///
/// Fully wired pipeline:
///   AI Agent 3D Orb ←→ TTS/STT ←→ AI Model Manager
///   ←→ Google SERP API ←→ GlassInputPanel ←→ TopControlPanel
///
/// The orb animates when AI is talking (isTalking from TTS).
/// Messages are reactive from VoiceController.
/// The active model shown in TopControlPanel updates per query.
///
/// EXPANDED MODE FEATURE:
///   - Double tap the AI Orb to toggle expanded/collapsed layout
///   - Expanded mode hides TopControlPanel (moves completely out of safe area)
///   - All content (Date, Orb, Indicators, Messages) slides up smoothly
///   - Provides maximum screen space for reading messages (5-6+ visible)
///   - 400ms sliding animations matching AI orb animation timing
///   - Bottom input panel stays fixed in place
/// ═══════════════════════════════════════════════════════════════
class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late final VoiceController _vc;
  late final IdlePromptService _idlePromptService;
  late final ProfileController _profileController;
  late final FamilyRelationshipManagerService _familyManager;
  late final HealthHygieneManagerService _healthManager;

  // ═══════════════════════════════════════════════════════════════
  // Layout Animation State
  // ═══════════════════════════════════════════════════════════════
  bool _isExpanded = false;
  late AnimationController _layoutController;
  late AnimationController
      _topPanelController; // Separate controller for top panel
  late Animation<Offset> _topPanelSlideAnimation;
  late Animation<double> _topPanelFadeAnimation;

  late Animation<double> _orbScaleAnimation;

  // Triple-tap tracking for hard reset
  int _tapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();

    // Register for app lifecycle callbacks
    WidgetsBinding.instance.addObserver(this);

    _vc = Get.find<VoiceController>();
    _idlePromptService = Get.find<IdlePromptService>();
    _profileController = Get.find<ProfileController>();

    // ── Initialize Query Prediction Controller ──
    Get.put(QueryPredictionController());

    // ── Initialize Family Relationship Manager ──
    _initializeFamilyManager();

    // ── Initialize Health & Hygiene Manager ──
    _initializeHealthManager();

    // ── Pre-test AI Models in background ──
    try {
      Get.find<AIModelManager>().initializeHealthChecks();
    } catch (_) {}

    _loadUserProfile();
    _setupInteractionListeners();
    _initializeAnimations();

    // Use the completely fresh and independent Voice Session Restoration Architecture
    // to strictly guarantee survival of mic state from Global Radio / World TV.
    unawaited(VoiceSessionRestorationManager.to.restore());

    // Start Enhanced Greeting Flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      EnhancedGreetingService.to.initializeGreetings();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route observer
    try {
      final route = ModalRoute.of(context);
      if (route != null) {
        routeObserver.subscribe(this, route);
      }
    } catch (_) {}
  }

  @override
  void didPopNext() {
    // Called when the top route is popped off and this screen is visible again.
    // Covers in-app navigation recovery: Radio/TV/Games → VoiceChat.
    debugPrint('🔄 [VoiceChatScreen] didPopNext — restoring voice state');

    // Run the independent Voice Session Restoration Architecture
    unawaited(VoiceSessionRestorationManager.to.restore());

    // Restart greetings AFTER the STT restore completes (worst case ~10 s).
    // Using 15 s ensures the restore loop has fully finished.
    Future.delayed(const Duration(milliseconds: 15000), () {
      if (!mounted) return;
      try {
        EnhancedGreetingService.to.initializeGreetings();
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-initialize when returning from game screen or background
      unawaited(VoiceSessionRestorationManager.to.restore());
    }
  }

  /// Initialize Family Relationship Manager and setup family interaction hooks
  void _initializeFamilyManager() {
    try {
      _familyManager = Get.find<FamilyRelationshipManagerService>();

      // Listen for specific family-related queries
      ever(_vc.messages, (_) {
        _handlePotentialFamilyInteraction();
      });

      debugPrint('✅ Family Relationship Manager initialized');
    } catch (e) {
      debugPrint('⚠️ Family Relationship Manager not available: $e');
    }
  }

  /// Handle potential family member introductions or requests
  void _handlePotentialFamilyInteraction() {
    if (_vc.messages.isEmpty) return;

    try {
      final lastUserMessage = _vc.messages.lastWhere(
        (msg) => msg.role == 'user',
        orElse: () => _vc.messages.first,
      );

      if (lastUserMessage.role != 'user') return;

      final userInput = lastUserMessage.content.toLowerCase();

      // Check for family member requests
      if (userInput.contains('talk to') ||
          userInput.contains('speak to') ||
          userInput.contains('chat with') ||
          userInput.contains('voice to')) {
        final memberType = _familyManager.detectFamilyMemberType(userInput);

        if (memberType != FamilyMemberType.other) {
          // Generate emotionally intelligent greeting for family member
          final greeting = _familyManager.generateFamilyMemberGreeting(
            memberType,
            userBehaviorContext: 'intelligent and curious learner',
          );

          // Queue this as the next AI response
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted) return;

            final familyMessage = ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              role: 'assistant',
              content: greeting,
              timestamp: DateTime.now(),
              modelName: 'Family Manager',
            );

            _vc.messages.add(familyMessage);
            _vc.speakMessage(familyMessage);
          });
        }
      }
    } catch (e) {
      debugPrint('Error handling family interaction: $e');
    }
  }

  // ── Health awareness de-duplication guard ─────────────────────────────────
  // Tracks the last safety context that triggered a health reminder and the
  // time it fired.  The same context is silenced for 30 s to prevent spam.
  SafetyContext? _lastHealthContext;
  DateTime? _lastHealthAt;

  /// Initialize Health & Hygiene Manager and setup health awareness hooks
  void _initializeHealthManager() {
    try {
      _healthManager = Get.find<HealthHygieneManagerService>();

      // Listen for user messages to detect health contexts
      ever(_vc.messages, (_) {
        _handleHealthAwareness();
      });

      debugPrint('✅ Health & Hygiene Manager initialized');
    } catch (e) {
      debugPrint('⚠️ Health & Hygiene Manager not available: $e');
    }
  }

  /// Handle health awareness detection and generate contextual health reminders
  void _handleHealthAwareness() {
    if (_vc.messages.isEmpty) return;

    try {
      // Find the last actual user message
      final lastUserMessage = _vc.messages.lastWhere(
        (msg) => msg.role == 'user',
        orElse: () => _vc.messages.first,
      );

      if (lastUserMessage.role != 'user') return;

      // ── Skip Read-Aloud messages — they are not AI queries ──────────────
      // Read-Aloud content is user-provided text that is read directly via TTS
      // without AI processing. Running health detection on it causes false
      // positives and duplicate assistant messages for every pasted paragraph.
      if (lastUserMessage.isReadAloud) return;

      final userInput = lastUserMessage.content.toLowerCase();

      // Detect safety context from user input
      final safetyContext = _healthManager.detectSafetyContext(userInput);

      // Only proceed if a non-normal context was detected
      if (safetyContext == SafetyContext.normal) return;

      // ── De-duplication guard: same context → 30 s cooldown ──────────────
      final now = DateTime.now();
      if (_lastHealthContext == safetyContext &&
          _lastHealthAt != null &&
          now.difference(_lastHealthAt!).inSeconds < 30) {
        debugPrint(
            '🛡️ [HealthManager] Skipping duplicate ${safetyContext.name} reminder (cooldown)');
        return;
      }
      _lastHealthContext = safetyContext;
      _lastHealthAt = now;

      // Generate context-aware health reminder if safety concerns detected
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;

        // Generate appropriate health response based on context
        final healthMessage = _healthManager.generateHealthReminder(
          safetyContext,
          userInput: userInput,
        );

        if (healthMessage.isNotEmpty) {
          final healthChatMessage = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: 'assistant',
            content: healthMessage,
            timestamp: DateTime.now(),
            modelName: 'Health Manager',
          );

          _vc.messages.add(healthChatMessage);
          _vc.speakMessage(healthChatMessage);
        }
      });
    } catch (e) {
      debugPrint('Error handling health awareness: $e');
    }
  }

  void _loadUserProfile() {
    try {
      final profile = _profileController.userProfile.value;
      final contextSummary = ProfileContextService.getContextSummary(profile);
      debugPrint('Profile Context Loaded: $contextSummary');
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  void _setupInteractionListeners() {
    ever(_vc.messages, (messages) {
      if (messages.isEmpty) {
        try {
          final orbController = Get.find<OrbThinkingController>();
          orbController.clearAvatar();
        } catch (_) {}
      }

      _idlePromptService.resetIdleTimer();
      // Notify orchestrator of user activity
      try {
        final orchestrator = Get.find<EngagementOrchestratorService>();
        orchestrator.onUserActivity();
      } catch (_) {}
    });
  }

  void _initializeAnimations() {
    // Animation duration for layout changes - 2x faster (200ms)
    _layoutController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Top panel controller - 2x faster (50ms) for smooth transitions
    _topPanelController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    );

    // Top panel slide animation - matches DefaultLayout exactly
    // Slides from top (-1.0) to normal position (0)
    _topPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _topPanelController,
      curve: Curves.easeOutCubic,
    ));

    // Top panel fade animation - matches DefaultLayout exactly
    _topPanelFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _topPanelController,
      curve: Curves.easeOut,
    ));

    // Orb scales slightly when interacting
    _orbScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _layoutController,
      curve: Curves.easeInOutCubic,
    ));

    // Start the top panel entrance animation
    _topPanelController.forward(from: 0.0);
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}

    _layoutController.dispose();
    _topPanelController.dispose();

    // FIX 3: Reset STT/TTS when leaving voice_chat_screen to prevent interference with other screens
    try {
      final sttService = Get.find<STTService>();
      if (sttService.isListening.value) {
        sttService.cancelListening(); // Hard cancel STT
        debugPrint('🔄 [VoiceChatScreen] STT stopped on dispose');
      }
    } catch (e) {
      debugPrint('⚠️ [VoiceChatScreen] Error stopping STT: $e');
    }

    try {
      final ttsService = Get.find<TTSService>();
      if (ttsService.isSpeaking.value) {
        ttsService.stop();
        debugPrint('🔄 [VoiceChatScreen] TTS stopped on dispose');
      }
    } catch (e) {
      debugPrint('⚠️ [VoiceChatScreen] Error stopping TTS: $e');
    }

    // Stop engagement orchestrator when leaving screen
    try {
      final orchestrator = Get.find<EngagementOrchestratorService>();
      orchestrator.stopEngagement();
      debugPrint('✅ [VoiceChatScreen] Engagement orchestrator stopped');
    } catch (e) {
      debugPrint('⚠️ [VoiceChatScreen] Error stopping orchestrator: $e');
    }

    // Force clear the thinking avatar when leaving screen to prevent it from showing on other screens
    try {
      final orbController = Get.find<OrbThinkingController>();
      orbController.clearAvatar();
    } catch (_) {}

    try {
      EnhancedGreetingService.to.resetForReentry();
    } catch (e) {
      debugPrint('⚠️ [VoiceChatScreen] Error resetting greeting service: $e');
    }

    // ENHANCEMENT: Reset controller state explicitly to ensure clean handoff
    try {
      _vc.stopSpeaking();
    } catch (_) {}
    if (_vc.isTalking.value) {
      _vc.isTalking.value = false;
      debugPrint('🔄 [VoiceChatScreen] Reset controller isTalking state');
    }

    // ENHANCEMENT: Clear any pending callbacks or listeners
    try {
      _idlePromptService.stopIdleTimer();
      debugPrint('🔄 [VoiceChatScreen] Stopped idle prompt service');
    } catch (e) {
      debugPrint('⚠️ [VoiceChatScreen] Error stopping idle service: $e');
    }

    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // Gesture Handlers - Enhanced with better timing and visual feedback
  // ═══════════════════════════════════════════════════════════════
  Timer? _tapTimer;
  void _handleOrbTap() {
    final now = DateTime.now();

    // Reset tap count if too much time has passed (500ms window)
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds > 500) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTapTime = now;

    // Show immediate visual feedback for tap registration
    HapticFeedback.lightImpact();
    _showTapFeedback(_tapCount);

    // Cancel previous timer and reschedule for faster processing (300ms)
    _tapTimer?.cancel();

    _tapTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final count = _tapCount;
      _tapCount = 0; // Reset
      _lastTapTime = null;

      if (count >= 3) {
        _handleTripleTap();
      } else if (count == 2) {
        _handleDoubleTap();
      } else if (count == 1) {
        _handleSingleTap();
      }
    });
  }

  // ── Glassmorphic snackbar helper ────────────────────────────────────────
  // Matches the dual-mode input panel: white-alpha gradient, coloured border,
  // backdrop blur, rounded pill shape — no opaque solid backgrounds.
  void _showGlassToast({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    Get.rawSnackbar(
      duration: duration,
      snackPosition: SnackPosition.TOP,
      margin: EdgeInsets.fromLTRB(
          context.r.scale(16), context.r.scale(12), context.r.scale(16), 0),
      borderRadius: 24,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      snackStyle: SnackStyle.FLOATING,
      messageText: ClipRRect(
        borderRadius: BorderRadius.circular(context.r.scale(24)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withAlpha(40),
                Colors.white.withAlpha(18),
                accentColor.withAlpha(28),
              ],
            ),
            borderRadius: BorderRadius.circular(context.r.scale(24)),
            border: Border.all(
              color: accentColor.withAlpha(110),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(55),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 30,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Padding(
              padding: context.r.symmetric(h: 18, v: 12),
              child: Row(
                children: [
                  Container(
                    padding: context.r.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(45),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: accentColor.withAlpha(100), width: 1),
                    ),
                    child: Icon(icon,
                        color: accentColor, size: context.r.scale(18)),
                  ),
                  const RSizedBox(w: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: context.r.sp(13),
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withAlpha(240),
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const RSizedBox(h: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: context.r.sp(11),
                              color: Colors.white.withAlpha(170),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show immediate visual feedback for tap count
  void _showTapFeedback(int tapCount) {
    switch (tapCount) {
      case 1:
        _showGlassToast(
          icon: Icons.touch_app_rounded,
          title: 'Single Tap — Chat cleared',
          subtitle: 'Double-tap to expand · Triple-tap to full reset',
          accentColor: const Color(0xFF64B5F6), // soft blue
          duration: const Duration(milliseconds: 1600),
        );
        break;
      case 2:
        // Note: _isExpanded is still the OLD value here (toggle happens in _handleDoubleTap).
        // So !_isExpanded is what it WILL become.
        _showGlassToast(
          icon: !_isExpanded
              ? Icons.open_in_full_rounded
              : Icons.close_fullscreen_rounded,
          title: !_isExpanded ? 'Expanding View' : 'Collapsing View',
          subtitle: !_isExpanded
              ? 'Maximum space for reading messages'
              : 'Top panel restored with full controls',
          accentColor: const Color(0xFFFFB74D), // soft amber
          duration: const Duration(milliseconds: 1800),
        );
        break;
      case 3:
      default:
        _showGlassToast(
          icon: Icons.refresh_rounded,
          title: 'Hard Reset',
          subtitle: 'Mic, memory \u0026 AI models reset — fresh start!',
          accentColor: const Color(0xFFEF9A9A), // soft rose
          duration: const Duration(milliseconds: 2400),
        );
        break;
    }
  }

  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();

    setState(() {
      _isExpanded = !_isExpanded;
    });

    // _showTapFeedback(2) already called by _showTapFeedback — no duplicate snackbar needed.

    if (_isExpanded) {
      // Animate top panel OUT (slide up and fade out)
      _topPanelController.animateTo(0.0,
          duration: const Duration(milliseconds: 200));
      _layoutController.forward();
    } else {
      // Animate top panel IN (slide down and fade in)
      _topPanelController.animateTo(1.0,
          duration: const Duration(milliseconds: 200));
      _layoutController.reverse();
    }
  }

  void _handleSingleTap() {
    HapticFeedback.lightImpact();

    // ── INSTANT RESET: stop TTS + STT immediately ────────────────────────
    // This prevents the orb from continuing to lip-sync after the tap
    // because stopSpeaking() sets isTalking = false right away.
    try {
      _vc.stopSpeaking(); // cancels chunk controller, clears isTalking, clears highlights
    } catch (_) {}
    try {
      Get.find<STTService>().cancelListening();
    } catch (_) {}

    // Clear all messages and orb avatar
    _vc.clearChat();
    try {
      Get.find<OrbThinkingController>().clearAvatar();
    } catch (_) {}

    // Toast shown by _showTapFeedback(1) — nothing more needed here
  }

  /// Triple-tap = Hard Reset (Emergency Reset) for Voice Chat Screen
  ///
  /// Resets STT, TTS, conversation memory, AI model blacklist,
  /// preferred model, and re-tests all 14 models fresh.
  void _handleTripleTap() {
    HapticFeedback.heavyImpact();
    debugPrint('🔄 [VoiceChatScreen] Hard Reset triggered by triple-tap');

    // 1. Stop TTS/STT immediately
    try {
      _vc.stopSpeaking();
      _vc.isTalking.value = false;
    } catch (_) {}

    try {
      final stt = Get.find<STTService>();
      stt.cancelListening();
    } catch (_) {}

    try {
      final tts = Get.find<TTSService>();
      tts.stop();
    } catch (_) {}

    // 2. Pause engagement services so they don't fire mid-reset
    try {
      Get.find<IdlePromptService>().stopIdleTimer();
    } catch (_) {}
    try {
      Get.find<EngagementOrchestratorService>().stopEngagement();
    } catch (_) {}
    try {
      Get.find<EnhancedGreetingService>().pauseService();
    } catch (_) {}

    // 3. Clear Orb thinking avatar
    try {
      Get.find<OrbThinkingController>().clearAvatar();
    } catch (_) {}

    // 4. Clear all messages (conversation memory)
    _vc.clearChat();

    // 5. Hard reset AI model manager
    try {
      Get.find<AIModelManager>().hardReset();
    } catch (_) {}

    // 6. Collapse expanded layout so everything is back to default - 2x faster
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _topPanelController.animateTo(1.0,
          duration: const Duration(milliseconds: 200));
      _layoutController.reverse();
    }

    // 7. Resume services after short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      try {
        Get.find<EnhancedGreetingService>().resumeService();
      } catch (_) {}
    });

    // 8. Visual feedback toast shown by _showTapFeedback(3) — no duplicate needed here
    HapticFeedback.mediumImpact();
    debugPrint('✅ [VoiceChatScreen] Hard Reset complete');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      currentRoute: AppRoutes.voiceChat,
      useDualModeInput: true,
      onMicToggle: () {
        // This is called when voice input provides text
        // The DualModeInputPanel already handles STT → text
        // We just need to trigger processVoiceInput when final text arrives
      },
      onStop: () {
        // Stop TTS when user presses stop
        _vc.stopSpeaking();
      },
      customTopPanel: SizeTransition(
        sizeFactor: _topPanelFadeAnimation,
        axisAlignment: -1.0,
        child: SlideTransition(
          position: _topPanelSlideAnimation,
          child: FadeTransition(
            opacity: _topPanelFadeAnimation,
            child: Padding(
              padding: EdgeInsets.only(
                  top: context.r.scale(16), bottom: context.r.scale(16)),
              child: TopControlPanel(currentRoute: AppRoutes.voiceChat),
            ),
          ),
        ),
      ),
      content: TabletConstrained(
        child: Obx(() {
          return AnimatedBuilder(
            animation: _layoutController,
            builder: (context, child) {
              return child!;
            },
            child: Column(
              children: [
                // ── Selection Mode Toolbar ─────────────────
                if (_vc.isSelectionMode.value) _buildSelectionToolbar(),

                // ── Compact Header (Date + Orb + Indicators) ─────────────────
                AnimatedBuilder(
                  animation: _layoutController,
                  builder: (context, child) {
                    return Container(
                      padding: EdgeInsets.only(
                        top: _isExpanded
                            ? 12
                            : 8, // Minimal top padding when expanded
                        bottom: _isExpanded ? 4 : 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Date Divider - smaller in expanded mode
                          if (!_isExpanded) ...[
                            Center(
                              child: Container(
                                padding: context.r.symmetric(h: 12, v: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800]!.withAlpha(26),
                                  borderRadius: BorderRadius.circular(
                                      context.r.scale(20)),
                                ),
                                child: Text(
                                  'TODAY',
                                  style: TextStyle(
                                    fontSize: context.r.sp(10),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const RSizedBox(h: 12),
                          ],

                          // AI Agent 3D Orb with Gesture Detection & Mood Indicator
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Orb
                              Semantics(
                                label: 'AI assistant orb',
                                button: true,
                                child: GestureDetector(
                                    onTap: _handleOrbTap,
                                    child: AnimatedBuilder(
                                      animation: _orbScaleAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _orbScaleAnimation.value,
                                          child: child,
                                        );
                                      },
                                      child: RepaintBoundary(
                                        child: Obx(() => AnimatedOrb(
                                              size: context.r.scale(
                                                  100), // Always keeping large size
                                              isTalking: _vc.isTalking
                                                  .value, // Enhanced lip sync
                                              showTalkingAnimation:
                                                  _vc.isTalking.value,
                                              autoBlink: true,
                                            )),
                                      ),
                                    )),
                              ),
                              // Thought Bubble - positioned above and to the right of orb
                              Obx(() {
                                final orbController =
                                    Get.find<OrbThinkingController>();
                                return Positioned(
                                  right: context.r.scale(-45),
                                  top: context.r.scale(-45),
                                  child: ThoughtBubbleWidget(
                                    avatarAssetPath:
                                        orbController.currentAvatarPath ?? '',
                                    visible: orbController.showCloud &&
                                        orbController.currentAvatarPath != null,
                                    size: context.r.scale(65),
                                  ),
                                );
                              }),
                            ],
                          ),

                          // Processing Stage & Model Badge - inline when expanded
                          if (_isExpanded)
                            Padding(
                              padding: EdgeInsets.only(top: context.r.scale(4)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Processing Stage
                                  Obx(() {
                                    final qh = Get.find<QueryHandlerService>();
                                    final stage = qh.processingStage.value;
                                    if (stage.isEmpty && !_vc.isLoading.value) {
                                      return const SizedBox.shrink();
                                    }
                                    return Container(
                                      padding: context.r.symmetric(h: 10, v: 4),
                                      margin: EdgeInsets.only(
                                          right: context.r.scale(8)),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(51),
                                        borderRadius: BorderRadius.circular(
                                            context.r.scale(16)),
                                        border: Border.all(
                                          color: Colors.white.withAlpha(38),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: context.r.scale(10),
                                            height: context.r.scale(10),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.grey[400]!,
                                              ),
                                            ),
                                          ),
                                          const RSizedBox(w: 6),
                                          Text(
                                            stage.isNotEmpty
                                                ? stage
                                                : 'Thinking...',
                                            style: TextStyle(
                                              fontSize: context.r.sp(10),
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  // Model Badge
                                  Obx(() {
                                    final model = _vc.activeModelName.value;
                                    return Container(
                                      padding: context.r.symmetric(h: 8, v: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withAlpha(38),
                                        borderRadius: BorderRadius.circular(
                                            context.r.scale(12)),
                                        border: Border.all(
                                          color: Colors.purple.withAlpha(77),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        model,
                                        style: TextStyle(
                                          fontSize: context.r.sp(9),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple[300],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            )
                          else ...[
                            const RSizedBox(h: 8),
                            // Processing Stage Indicator
                            Obx(() {
                              final qh = Get.find<QueryHandlerService>();
                              final stage = qh.processingStage.value;
                              if (stage.isEmpty && !_vc.isLoading.value) {
                                return const SizedBox.shrink();
                              }
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  key: ValueKey(stage),
                                  padding: context.r.symmetric(h: 16, v: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(51),
                                    borderRadius: BorderRadius.circular(
                                        context.r.scale(20)),
                                    border: Border.all(
                                      color: Colors.white.withAlpha(38),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: context.r.scale(14),
                                        height: context.r.scale(14),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.grey[400]!,
                                          ),
                                        ),
                                      ),
                                      const RSizedBox(w: 8),
                                      Text(
                                        stage.isNotEmpty
                                            ? stage
                                            : 'Thinking...',
                                        style: TextStyle(
                                          fontSize: context.r.sp(12),
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const RSizedBox(h: 4),
                            // ── Tappable active model badge: opens model picker ──
                            Obx(() {
                              final model = _vc.activeModelName.value;
                              return Semantics(
                                label: 'Current model: $model',
                                button: true,
                                child: GestureDetector(
                                  onTap: _showModelPicker,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Container(
                                      key: ValueKey(model),
                                      padding: context.r.symmetric(h: 10, v: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withAlpha(38),
                                        borderRadius: BorderRadius.circular(
                                            context.r.scale(12)),
                                        border: Border.all(
                                          color: Colors.purple.withAlpha(128),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            model,
                                            style: TextStyle(
                                              fontSize: context.r.sp(10),
                                              fontWeight: FontWeight.w600,
                                              color: Colors.purple[300],
                                            ),
                                          ),
                                          const RSizedBox(w: 4),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: context.r.scale(12),
                                            color: Colors.purple[300],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    );
                  },
                ),

                // ── Chat Messages ─────────────────────────────
                Expanded(
                  child: Stack(
                    children: [
                      // Message list
                      _vc.messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: context.r.scale(48),
                                    color: Colors.grey[400],
                                  ),
                                  const RSizedBox(h: 16),
                                  Text(
                                    'Ask me anything...',
                                    style: TextStyle(
                                      fontSize: context.r.sp(14),
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const RSizedBox(h: 8),
                                  Text(
                                    'Double tap the orb to expand chat',
                                    style: TextStyle(
                                      fontSize: context.r.sp(12),
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _vc.scrollController,
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    context.r.scale(_isExpanded ? 2 : 4),
                                vertical: context.r.scale(_isExpanded ? 2 : 8),
                              ),
                              itemCount: _vc.messages.length +
                                  1, // +1 for suggestion bubble
                              cacheExtent: 400,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: false,
                              itemBuilder: (context, index) {
                                // If this is the last index (beyond messages), show suggestion bubble
                                if (index >= _vc.messages.length) {
                                  return const SuggestionBubble();
                                }

                                final msg = _vc.messages[index];
                                if (msg.role == 'assistant') {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          context.r.scale(_isExpanded ? 3 : 12),
                                    ),
                                    child: _buildAssistantMessage(msg, index),
                                  );
                                } else {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          context.r.scale(_isExpanded ? 3 : 12),
                                    ),
                                    child: _buildUserMessage(msg, index),
                                  );
                                }
                              },
                            ),

                      // ── Scroll Navigation Buttons (right-center) ──
                      if (_vc.messages.isNotEmpty)
                        Positioned(
                          right: context.r.scale(8),
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildScrollNavButton(
                                  Icons.keyboard_arrow_up_rounded,
                                  _scrollToTop,
                                ),
                                const RSizedBox(h: 6),
                                _buildScrollNavButton(
                                  Icons.keyboard_arrow_down_rounded,
                                  _scrollToBottom,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Scroll Navigation — jump to top / bottom of message list
  // ═══════════════════════════════════════════════════════════════

  void _scrollToTop() {
    if (_vc.scrollController.hasClients) {
      _vc.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToBottom() {
    if (_vc.scrollController.hasClients) {
      _vc.scrollController.animateTo(
        _vc.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildScrollNavButton(IconData icon, VoidCallback onTap) {
    final label = icon == Icons.keyboard_arrow_up
        ? 'Scroll to top'
        : icon == Icons.keyboard_arrow_down
            ? 'Scroll to bottom'
            : 'Scroll';
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: context.r.scale(32),
          height: context.r.scale(32),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(38),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha(77),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white.withAlpha(204),
            size: context.r.scale(18),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Model Picker — lets user choose their preferred AI model
  // ═══════════════════════════════════════════════════════════════

  /// Show a glassmorphic backdrop listing all AI models with health status.
  /// User can tap to lock a model, or tap Auto to restore routing.
  void _showModelPicker() {
    HapticFeedback.lightImpact();

    AIModelManager? aiManager;
    try {
      aiManager = Get.find<AIModelManager>();
    } catch (_) {
      return; // Service not available
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(128),
      builder: (ctx) => _buildModelPickerSheet(aiManager!),
    );
  }

  Widget _buildModelPickerSheet(AIModelManager aiManager) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return AIModelSelectorBackdrop(aiManager: aiManager);
      },
    );
  }

  /// Build assistant message bubble with mini orb and read aloud button
  Widget _buildAssistantMessage(ChatMessage msg, int index) {
    final isSelected = _vc.selectedMessageIds.contains(msg.id);
    final isSelectionMode = _vc.isSelectionMode.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'AI message',
          child: GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _vc.toggleMessageSelection(msg.id);
            },
            onTap: isSelectionMode
                ? () {
                    HapticFeedback.lightImpact();
                    _vc.toggleMessageSelection(msg.id);
                  }
                : null,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Selection checkbox (visible in selection mode)
                    if (isSelectionMode)
                      Container(
                        margin: EdgeInsets.only(
                            right: context.r.scale(_isExpanded ? 6 : 8)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: context.r.scale(_isExpanded ? 20 : 24),
                          height: context.r.scale(_isExpanded ? 20 : 24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.purple.withAlpha(204)
                                : Colors.white.withAlpha(51),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.purple
                                  : Colors.white.withAlpha(128),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: context.r.scale(_isExpanded ? 14 : 16),
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    // Mini AI Orb avatar — smaller when expanded (hidden in selection mode for assistant)
                    // Uses MessageOrb for synchronized lip sync and eye blinking with primary orb
                    if (!isSelectionMode)
                      MessageOrb(
                        messageId: msg.id,
                        size: context.r.scale(_isExpanded ? 24 : 36),
                      ),
                    if (!isSelectionMode) RSizedBox(w: _isExpanded ? 6 : 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label + model badge + read aloud button - hide in expanded mode for more space
                          if (!_isExpanded && !isSelectionMode)
                            Padding(
                              padding: EdgeInsets.only(
                                left: context.r.scale(4),
                                bottom: context.r.scale(4),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'CTJ AI',
                                    style: TextStyle(
                                      fontSize: context.r.sp(10),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Read aloud button for assistant message
                                  _buildReadAloudButton(msg),
                                ],
                              ),
                            ),
                          // Message bubble - much more compact when expanded
                          Stack(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(
                                        context.r.scale(_isExpanded ? 12 : 16)),
                                    topRight: Radius.circular(
                                        context.r.scale(_isExpanded ? 12 : 16)),
                                    bottomRight: Radius.circular(
                                        context.r.scale(_isExpanded ? 12 : 16)),
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.purple.withAlpha(128),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: GlassContainer(
                                  padding: EdgeInsets.all(
                                      context.r.scale(_isExpanded ? 8 : 14)),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(
                                        context.r.scale(_isExpanded ? 12 : 16)),
                                    topRight: Radius.circular(
                                        context.r.scale(_isExpanded ? 12 : 16)),
                                    bottomRight: Radius.circular(
                                        context.r.scale(_isExpanded ? 12 : 16)),
                                  ),
                                  backgroundColor: isSelected
                                      ? Colors.purple.withAlpha(77)
                                      : Colors.white.withAlpha(64),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.purple.withAlpha(179)
                                        : Colors.white.withAlpha(77),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  child: Builder(
                                    builder: (context) => TtsAwareMessageBody(
                                      message: msg,
                                      highlightColor: const Color(0xFFFFE082)
                                          .withAlpha(153),
                                      baseStyle: TextStyle(
                                        fontSize:
                                            context.r.sp(_isExpanded ? 12 : 14),
                                        height: _isExpanded ? 1.3 : 1.5,
                                        color: AppColors.textPrimary(context),
                                      ),
                                      isUserMessage: false,
                                    ),
                                  ),
                                ),
                              ),
                              // Read aloud button for expanded mode (inside bubble)
                              if (_isExpanded && !isSelectionMode)
                                Positioned(
                                  right: context.r.scale(4),
                                  bottom: context.r.scale(4),
                                  child: _buildCompactReadAloudButton(msg),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Badge Removed
              ],
            ),
          ),
        ),
        // ── Audio Export Panel (download / play / share / delete) ─────────
        if (!isSelectionMode)
          Padding(
            padding: EdgeInsets.only(
                left: context.r.scale(44), top: context.r.scale(4)),
            child: AudioExportPanel(
              messageId: msg.id,
              messageText: msg.content,
              brandingScreen: 'voiceChat',
              // ACCENT FIX: pass selected language so generated WAV uses proper voice
              languageCode: () {
                try {
                  return Get.find<LanguageController>()
                      .selectedLanguage
                      .value
                      .sttLocale;
                } catch (_) {
                  return null;
                }
              }(),
            ),
          ),
        // ── Curiosity Hook Option Chips ────────────────────────────────
        if (!isSelectionMode) _buildCuriosityChips(msg.content),
        // ── Speech Coach "Hear my version" Button ─────────────────────
        if (!isSelectionMode) _buildMyVersionButton(msg.content),
      ],
    );
  }

  /// Extracts the corrected version text from [MY_VERSION:<text>] tag.
  /// Returns null if tag absent.
  String? _parseMyVersion(String content) {
    final match = RegExp(
      r'\[MY_VERSION:([\s\S]+?)\](?:\s*)$',
      multiLine: true,
    ).firstMatch(content);
    return match?.group(1)?.trim();
  }

  Widget _buildMyVersionButton(String content) {
    final versionText = _parseMyVersion(content);
    if (versionText == null || versionText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
          left: context.r.scale(44),
          top: context.r.scale(8),
          bottom: context.r.scale(4)),
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.mediumImpact();
          try {
            // Stop any current TTS first
            _vc.stopSpeaking();
            await Future.delayed(const Duration(milliseconds: 150));

            // Speak the corrected version directly via TTS
            final msg2 = ChatMessage(
              id: 'myversion_${DateTime.now().millisecondsSinceEpoch}',
              role: 'assistant',
              content: versionText,
              timestamp: DateTime.now(),
            );
            _vc.speakMessage(msg2);
          } catch (e) {
            debugPrint('⚠️ MyVersion TTS error: $e');
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.r.scale(22)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: context.r.symmetric(h: 16, v: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF69B4).withAlpha(45),
                    const Color(0xFFFFB2EE).withAlpha(30),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(context.r.scale(22)),
                border: Border.all(
                  color: const Color(0xFFFF69B4).withAlpha(128),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF69B4).withAlpha(40),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing mic container
                  Container(
                    width: context.r.scale(32),
                    height: context.r.scale(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF69B4).withAlpha(51),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF69B4).withAlpha(153),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.mic,
                      size: context.r.scale(16),
                      color: Color(0xFFFF69B4),
                    ),
                  ),
                  const RSizedBox(w: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hear Palak\'s Version 🎤',
                        style: TextStyle(
                          fontSize: context.r.sp(13),
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF69B4),
                          letterSpacing: 0.2,
                        ),
                      ),
                      RSizedBox(h: 2),
                      Text(
                        'Tap to hear the improved speech',
                        style: TextStyle(
                          fontSize: context.r.sp(10),
                          color: Color(0xFF5A3E54),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const RSizedBox(w: 8),
                  Icon(
                    Icons.play_circle_outline,
                    color: Color(0xFFFF69B4),
                    size: context.r.scale(20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Parses [OPTIONS:A:<q>|B:<q>|C:<q>] from AI response content.
  /// Returns list of (label, question) pairs, or empty if no tag found.
  List<(String, String)> _parseCuriosityOptions(String content) {
    final match = RegExp(
      r'\[OPTIONS:A:(.+?)\|B:(.+?)\|C:(.+?)\]',
      dotAll: true,
    ).firstMatch(content);
    if (match == null) return [];
    return [
      ('A', match.group(1)!.trim()),
      ('B', match.group(2)!.trim()),
      ('C', match.group(3)!.trim()),
    ];
  }

  Widget _buildCuriosityChips(String content) {
    final options = _parseCuriosityOptions(content);
    if (options.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
          left: context.r.scale(44),
          top: context.r.scale(6),
          bottom: context.r.scale(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: context.r.scale(6)),
            child: Text(
              '🤔 Explore more:',
              style: TextStyle(
                fontSize: context.r.sp(11),
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final label = opt.$1;
              final question = opt.$2;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _vc.sendTextDirectly(question);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(context.r.scale(20)),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: context.r.symmetric(h: 12, v: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB2EE).withAlpha(38),
                        borderRadius:
                            BorderRadius.circular(context.r.scale(20)),
                        border: Border.all(
                          color: const Color(0xFFFFB2EE).withAlpha(102),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: context.r.scale(20),
                            height: context.r.scale(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF69B4).withAlpha(51),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: context.r.sp(10),
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF69B4),
                                ),
                              ),
                            ),
                          ),
                          const RSizedBox(w: 6),
                          ConstrainedBox(
                            constraints:
                                BoxConstraints(maxWidth: context.r.scale(220)),
                            child: Text(
                              question,
                              style: TextStyle(
                                fontSize: context.r.sp(12),
                                color: Color(0xFF5A3E54),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Build user message bubble with read aloud button
  Widget _buildUserMessage(ChatMessage msg, int index) {
    final isSelected = _vc.selectedMessageIds.contains(msg.id);
    final isSelectionMode = _vc.isSelectionMode.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _vc.toggleMessageSelection(msg.id);
          },
          onTap: isSelectionMode
              ? () {
                  HapticFeedback.lightImpact();
                  _vc.toggleMessageSelection(msg.id);
                }
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Read aloud button for user message (left side) - hidden in selection mode
              if (!_isExpanded && !isSelectionMode) ...[
                _buildReadAloudButton(msg, forUserMessage: true),
                const RSizedBox(w: 6),
              ],
              Flexible(
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding:
                          EdgeInsets.all(context.r.scale(_isExpanded ? 8 : 14)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSelected
                              ? [
                                  const Color(0xFFFF69B4),
                                  const Color(0xFFFF1493),
                                ]
                              : [
                                  const Color(0xFFFFB2EE),
                                  const Color(0xFFFF69B4),
                                ],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(
                              context.r.scale(_isExpanded ? 12 : 16)),
                          topRight: Radius.circular(
                              context.r.scale(_isExpanded ? 12 : 16)),
                          bottomLeft: Radius.circular(
                              context.r.scale(_isExpanded ? 12 : 16)),
                        ),
                        boxShadow: isSelected
                            ? [
                                const BoxShadow(
                                  color: Color(0x80FF1493),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ]
                            : _isExpanded
                                ? null
                                : const [
                                    BoxShadow(
                                      color: Color(0x40FFB2EE),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                      ),
                      child: TtsAwareMessageBody(
                        message: msg,
                        highlightColor: const Color(0xFFFFE082)
                            .withAlpha(153), // Transparent yellow
                        baseStyle: TextStyle(
                          fontSize: context.r.sp(_isExpanded ? 12 : 14),
                          height: _isExpanded ? 1.3 : 1.5,
                          color: Colors.white,
                        ),
                        isUserMessage: true,
                      ),
                    ),
                    // Read aloud button for expanded mode (inside bubble)
                    if (_isExpanded && !isSelectionMode)
                      Positioned(
                        left: context.r.scale(4),
                        bottom: context.r.scale(4),
                        child: _buildCompactReadAloudButton(msg,
                            forUserMessage: true),
                      ),
                  ],
                ),
              ),
              // Selection checkbox (visible in selection mode)
              if (isSelectionMode)
                Container(
                  margin: EdgeInsets.only(
                      left: context.r.scale(_isExpanded ? 6 : 8)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: context.r.scale(_isExpanded ? 20 : 24),
                    height: context.r.scale(_isExpanded ? 20 : 24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.pink.withAlpha(204)
                          : Colors.white.withAlpha(51),
                      border: Border.all(
                        color: isSelected
                            ? Colors.pink
                            : Colors.white.withAlpha(128),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: context.r.scale(_isExpanded ? 14 : 16),
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),

        // ── Audio Export Panel for Read-Aloud messages ────────────────────
        // Shown only when this user message was created via the "Read" button,
        // NOT for normal AI-query user messages. Hidden in selection mode.
        if (msg.isReadAloud && !isSelectionMode)
          Padding(
            padding: EdgeInsets.only(top: context.r.scale(4)),
            child: AudioExportPanel(
              messageId: msg.id,
              messageText: msg.content,
              brandingScreen: 'voiceChat',
              languageCode: () {
                try {
                  return Get.find<LanguageController>()
                      .selectedLanguage
                      .value
                      .sttLocale;
                } catch (_) {
                  return null;
                }
              }(),
            ),
          ),
      ],
    );
  }

  /// Build read aloud button for messages
  Widget _buildReadAloudButton(ChatMessage msg, {bool forUserMessage = false}) {
    return Obx(() {
      // Enhanced state detection - check if THIS message is the active speaking message
      final isThisMessageActive = _vc.currentSpeakingMessageId.value == msg.id;
      final isTTSSpeaking = _vc.isTalking.value;
      // Consider playing if this message is active AND TTS is speaking
      final isCurrentlyPlaying = isThisMessageActive && isTTSSpeaking;

      return GestureDetector(
        onTap: () async {
          HapticFeedback.lightImpact();

          if (isCurrentlyPlaying) {
            // ── STOP: This message is currently playing → stop it ──
            debugPrint(
                '🔇 [ReadAloud] Stopping playback for message: ${msg.id}');
            await _vc.stopSpeaking();
          } else {
            // ── PLAY: Start playing this message ──
            debugPrint(
                '🔊 [ReadAloud] Starting playback for message: ${msg.id}');

            // If another message is already playing, stop it first then yield
            final isAnyMessagePlaying = _vc.isTalking.value &&
                _vc.currentSpeakingMessageId.value.isNotEmpty;
            if (isAnyMessagePlaying) {
              await _vc.stopSpeaking();
              await Future.delayed(const Duration(milliseconds: 100));
            }

            // CRITICAL FIX: Do NOT await speakMessage — it blocks until TTS finishes,
            // making the stop tap impossible. Fire-and-forget so the button stays live.
            unawaited(_vc.speakMessage(msg));
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: context.r.all(6),
          decoration: BoxDecoration(
            color: isCurrentlyPlaying
                ? (forUserMessage
                    ? Colors.red.withAlpha(102)
                    : Colors.red.withAlpha(51))
                : (forUserMessage
                    ? Colors.white.withAlpha(102)
                    : Colors.purple.withAlpha(51)),
            borderRadius: BorderRadius.circular(context.r.scale(12)),
            border: Border.all(
              color: isCurrentlyPlaying
                  ? (forUserMessage
                      ? Colors.red.withAlpha(153)
                      : Colors.red.withAlpha(128))
                  : (forUserMessage
                      ? Colors.white.withAlpha(153)
                      : Colors.purple.withAlpha(128)),
              width: 1,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              isCurrentlyPlaying ? Icons.stop : Icons.volume_up,
              key: ValueKey(isCurrentlyPlaying),
              size: context.r.scale(16),
              color: isCurrentlyPlaying
                  ? (forUserMessage ? Colors.red[300] : Colors.red[400])
                  : (forUserMessage ? Colors.white : Colors.purple[400]),
            ),
          ),
        ),
      );
    });
  }

  /// Build compact read aloud button for expanded mode
  Widget _buildCompactReadAloudButton(ChatMessage msg,
      {bool forUserMessage = false}) {
    return Obx(() {
      // Enhanced state detection - check if THIS message is the active speaking message
      final isThisMessageActive = _vc.currentSpeakingMessageId.value == msg.id;
      final isTTSSpeaking = _vc.isTalking.value;
      // Consider playing if this message is active AND TTS is speaking
      final isCurrentlyPlaying = isThisMessageActive && isTTSSpeaking;

      return GestureDetector(
        onTap: () async {
          HapticFeedback.lightImpact();

          if (isCurrentlyPlaying) {
            // ── STOP: This message is currently playing → stop it ──
            debugPrint(
                '🔇 [CompactReadAloud] Stopping playback for message: ${msg.id}');
            await _vc.stopSpeaking();
          } else {
            // ── PLAY: Start playing this message ──
            debugPrint(
                '🔊 [CompactReadAloud] Starting playback for message: ${msg.id}');

            // If another message is already playing, stop it first then yield
            final isAnyMessagePlaying = _vc.isTalking.value &&
                _vc.currentSpeakingMessageId.value.isNotEmpty;
            if (isAnyMessagePlaying) {
              await _vc.stopSpeaking();
              await Future.delayed(const Duration(milliseconds: 100));
            }

            // CRITICAL FIX: Do NOT await speakMessage — it blocks until TTS finishes,
            // making the stop tap impossible. Fire-and-forget so the button stays live.
            unawaited(_vc.speakMessage(msg));
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: context.r.all(4),
          decoration: BoxDecoration(
            color: isCurrentlyPlaying
                ? (forUserMessage
                    ? Colors.red.withAlpha(77)
                    : Colors.red.withAlpha(38))
                : (forUserMessage
                    ? Colors.white.withAlpha(77)
                    : Colors.purple.withAlpha(38)),
            borderRadius: BorderRadius.circular(context.r.scale(8)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              isCurrentlyPlaying ? Icons.stop : Icons.volume_up,
              key: ValueKey(isCurrentlyPlaying),
              size: context.r.scale(14),
              color: isCurrentlyPlaying
                  ? (forUserMessage ? Colors.red[300] : Colors.red[400])
                  : (forUserMessage ? Colors.white70 : Colors.purple[300]),
            ),
          ),
        ),
      );
    });
  }

  /// Build glassmorphic selection toolbar with scrollable action buttons
  Widget _buildSelectionToolbar() {
    final selectedCount = _vc.selectedMessageIds.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(bottom: context.r.scale(8)),
      child: GlassContainer(
        padding: context.r.symmetric(h: 12, v: 10),
        borderRadius: BorderRadius.circular(context.r.scale(16)),
        backgroundColor: Colors.white.withAlpha(77),
        border: Border.all(
          color: Colors.white.withAlpha(153),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
        child: Row(
          children: [
            // Selected count badge
            Container(
              padding: context.r.symmetric(h: 10, v: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple[400]!,
                    Colors.purple[600]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(context.r.scale(10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withAlpha(77),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Text(
                '$selectedCount',
                style: TextStyle(
                  fontSize: context.r.sp(13),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const RSizedBox(w: 10),
            // Selected text - flexible to prevent overflow
            Flexible(
              child: Text(
                selectedCount == 1 ? 'selected' : 'selected',
                style: TextStyle(
                  fontSize: context.r.sp(12),
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const RSizedBox(w: 8),
            // Scrollable action buttons
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button
                    _buildToolbarButton(
                      icon: Icons.close,
                      color: Colors.grey,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _vc.selectedMessageIds.clear();
                        _vc.isSelectionMode.value = false;
                      },
                    ),
                    const RSizedBox(w: 6),
                    // Select All button
                    _buildToolbarButton(
                      icon: Icons.select_all,
                      color: Colors.grey,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _vc.selectAllMessages();
                      },
                    ),
                    const RSizedBox(w: 6),
                    // Copy button
                    _buildToolbarButton(
                      icon: Icons.copy,
                      color: Colors.blue,
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await _vc.copySelectedMessages();
                      },
                    ),
                    const RSizedBox(w: 6),
                    // Delete button
                    _buildToolbarButton(
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        _showDeleteConfirmation();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a consistent toolbar action button
  Widget _buildToolbarButton({
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: context.r.all(8),
        decoration: BoxDecoration(
          color: color[50]?.withAlpha(128),
          borderRadius: BorderRadius.circular(context.r.scale(10)),
          border: Border.all(
            color: color[200]!.withAlpha(128),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: context.r.scale(18),
          color: color[700],
        ),
      ),
    );
  }

  /// Show delete confirmation dialog with professional styling
  void _showDeleteConfirmation() {
    final selectedCount = _vc.selectedMessageIds.length;

    GlassmorphicDialogHelper.showDeleteConfirmation(
      title: 'Delete ${selectedCount == 1 ? 'Message' : 'Messages'}?',
      message:
          'Are you sure you want to delete $selectedCount ${selectedCount == 1 ? 'message' : 'messages'}?',
      subtitle: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      onConfirm: () {
        _vc.deleteSelectedMessages();

        // Clear avatar alongside messages
        try {
          Get.find<OrbThinkingController>().clearAvatar();
        } catch (_) {}

        Get.snackbar(
          'Deleted',
          '$selectedCount ${selectedCount == 1 ? 'message' : 'messages'} deleted',
          backgroundColor: Colors.red[400],
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(context.r.scale(16)),
          borderRadius: 12,
        );
      },
    );
  }
}
