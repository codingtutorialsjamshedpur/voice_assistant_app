import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/universal_voice_pipeline.dart';
import '../shared/theme/responsive.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/voice_memo_service.dart';
import '../services/sound_service.dart';
import '../services/read_aloud_service.dart';
import '../shared/controllers/top_panel_controller.dart';
import '../controllers/voice_controller.dart';
import '../controllers/language_controller.dart';
import '../features/orb_thinking/orb_thinking_controller.dart';
import 'language_picker_bottom_sheet.dart';

/// Input panel modes
enum InputPanelMode { chat, voiceMemo }

/// Language options for the panel
enum PanelLanguage { english, hindi, hinglish }

/// Dual-Mode Glass Panel Widget
///
/// Features:
/// - Mode A: Chat Input Mode (STT + Keyboard + Text Input)
/// - Mode B: Voice Memo Mode (Recording with pause/play/stop)
///
/// Uses toggle-based modality switch for better UX
///
/// IMPROVEMENTS:
/// - Expandable text area when typing (up to 5 lines)
/// - Smooth scrolling within text field
/// - Fixed text overflow for hints
/// - Better spacing and readability
class DualModeInputPanel extends StatefulWidget {
  final TextEditingController? textController;
  final Function(String)? onSendMessage;
  final Function(String)? onVoiceInput;
  final VoidCallback? onModeChanged;
  final double height;

  const DualModeInputPanel({
    super.key,
    this.textController,
    this.onSendMessage,
    this.onVoiceInput,
    this.onModeChanged,
    this.height = 72,
  });

  @override
  State<DualModeInputPanel> createState() => _DualModeInputPanelState();
}

class _DualModeInputPanelState extends State<DualModeInputPanel>
    with TickerProviderStateMixin {
  // Services
  late final TTSService _ttsService;
  late final STTService _sttService;
  late final VoiceMemoService _memoService;
  late final TopPanelController _topPanelController;
  LanguageController? _langController;

  // State
  final currentMode = InputPanelMode.chat.obs;
  final currentLanguage = PanelLanguage.hinglish.obs; // default until synced
  final isExpanded = false.obs;
  final showMemoLibrary = false.obs;
  final isKeyboardVisible = false.obs;
  final textFieldHeight = 48.0.obs; // Dynamic height for text field

  // Animation controllers
  late AnimationController _waveformController;
  late AnimationController _pulseController;
  late AnimationController _modeSwitchController;
  late AnimationController _expandController;
  late AnimationController _blinkController;

  // Blinking state for buttons
  final isClearBlinking = false.obs;
  final isReadBlinking = false.obs;
  final isSendBlinking = false.obs;

  // Reset state for manual reset button
  final showResetButton = false.obs;

  // Text controller
  late TextEditingController _textController;
  late FocusNode _textFocusNode;

  // Worker to listen for portal-return resets
  Worker? _uiResetWorker;

  @override
  void initState() {
    super.initState();

    // Initialize services
    _ttsService = Get.find<TTSService>();
    _sttService = Get.find<STTService>();
    _memoService = Get.find<VoiceMemoService>();
    _topPanelController = Get.find<TopPanelController>();

    // Sync language from persisted LanguageController
    try {
      _langController = Get.find<LanguageController>();
      final savedCode = _langController!.selectedLanguage.value.code;
      if (savedCode == 'en' || savedCode == 'en-US' || savedCode == 'en-GB') {
        currentLanguage.value = PanelLanguage.english;
      } else if (savedCode == 'hi') {
        currentLanguage.value = PanelLanguage.hindi;
      } else {
        currentLanguage.value = PanelLanguage.hinglish;
      }
    } catch (_) {
      // LanguageController not registered yet — default to Hindi
      currentLanguage.value = PanelLanguage.hindi;
    }

    // Initialize text controller and focus node
    _textController = widget.textController ?? TextEditingController();
    _textFocusNode = FocusNode();
    _textFocusNode.addListener(_onFocusChange);

    // ── Listen to portal-return reset signal ───────────────────────────────
    // When returning from Radio/TV, the stored text and "send" button state
    // from before the portal must be cleared so the mic button reappears.
    _uiResetWorker = ever(_sttService.uiResetSignal, (_) {
      if (mounted) {
        _textController.clear();
        showResetButton.value = false;
        debugPrint(
            '🧹 [DualModeInputPanel] Cleared UI state after portal return');
      }
    });

    // Initialize animations
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _modeSwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    // Blinking animation for buttons (disco style)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  void _onFocusChange() {
    isKeyboardVisible.value = _textFocusNode.hasFocus;
  }

  @override
  void dispose() {
    _uiResetWorker?.dispose();
    _waveformController.dispose();
    _pulseController.dispose();
    _modeSwitchController.dispose();
    _expandController.dispose();
    _blinkController.dispose();
    _textFocusNode.removeListener(_onFocusChange);
    _textFocusNode.dispose();
    if (widget.textController == null) {
      _textController.dispose();
    }
    super.dispose();
  }

  /// Toggle between modes
  void _toggleMode() {
    HapticFeedback.lightImpact();
    SoundService.to.playClick();

    currentMode.value = currentMode.value == InputPanelMode.chat
        ? InputPanelMode.voiceMemo
        : InputPanelMode.chat;

    _modeSwitchController.forward(from: 0);

    // Reset expansion state
    showMemoLibrary.value = false;
    isExpanded.value = false;
    _expandController.reverse();

    if (widget.onModeChanged != null) {
      widget.onModeChanged!();
    }

    // Cancel any ongoing activities
    if (currentMode.value == InputPanelMode.voiceMemo) {
      _sttService.stopListening();
      _textFocusNode.unfocus();
    } else {
      if (_memoService.isRecording.value) {
        _memoService.cancelRecording();
      }
      if (_memoService.isPlaying.value) {
        _memoService.stopPlayback();
      }
    }
  }

  /// Cycle through languages and PERSIST the selection via LanguageController
  void _cycleLanguage() {
    HapticFeedback.lightImpact();

    PanelLanguage nextLang;
    switch (currentLanguage.value) {
      case PanelLanguage.english:
        nextLang = PanelLanguage.hindi;
        _sttService.setLanguage(STTLanguage.hindi);
        _ttsService.setLanguage(TTSLanguage.hindi);
        break;
      case PanelLanguage.hindi:
        nextLang = PanelLanguage.hinglish;
        _sttService.setLanguage(STTLanguage.hinglish);
        _ttsService.setLanguage(TTSLanguage.hinglish);
        break;
      case PanelLanguage.hinglish:
        nextLang = PanelLanguage.english;
        _sttService.setLanguage(STTLanguage.englishUS);
        _ttsService.setLanguage(TTSLanguage.english);
        break;
    }
    currentLanguage.value = nextLang;

    // Persist selection via LanguageController so it survives app restarts
    try {
      _langController ??= Get.find<LanguageController>();
      final targetCode = nextLang == PanelLanguage.english
          ? 'en'
          : nextLang == PanelLanguage.hindi
              ? 'hi'
              : 'hinglish';
      final allLangs = _langController!.mainLanguages;
      final found = allLangs.where((l) => l.code == targetCode).toList();
      if (found.isNotEmpty) {
        _langController!.selectLanguage(found.first);
      }
    } catch (_) {}

    // Provide audio feedback in the SELECTED language
    _ttsService.speak('${_getLanguageName(nextLang)} selected');
  }

  String _getLanguageName(PanelLanguage lang) {
    switch (lang) {
      case PanelLanguage.english:
        return 'English';
      case PanelLanguage.hindi:
        return 'Hindi';
      case PanelLanguage.hinglish:
        return 'Hinglish';
    }
  }

  String _getLanguageFlag(PanelLanguage lang) {
    switch (lang) {
      case PanelLanguage.english:
        return '🇺🇸';
      case PanelLanguage.hindi:
        return '🇮🇳';
      case PanelLanguage.hinglish:
        return '🇮🇳';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentColor = _topPanelController.currentColor;
      final darkVariant = _topPanelController.getDarkVariant();

      // Try to get LanguageController (optional — safe if not yet registered)
      LanguageController? langCtrl;
      try {
        langCtrl = Get.find<LanguageController>();
      } catch (_) {}

      final isDownloadingLang = langCtrl?.isDownloading.value ?? false;
      final selectedLang = langCtrl?.selectedLanguage.value;
      final showLangLabel = selectedLang != null &&
          selectedLang.code != 'en-US' &&
          selectedLang.code != 'en-GB' &&
          selectedLang.code != 'hinglish';

      return AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOutCubic,
        height: widget.height +
            (isExpanded.value ? 200 : 0) +
            (showLangLabel ? 24 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin download progress indicator at top
            if (isDownloadingLang)
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(
                  value: langCtrl!.downloadProgress.value > 0
                      ? langCtrl.downloadProgress.value
                      : null,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            // Main Panel
            Container(
              height: widget.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha(38),
                    Colors.white.withAlpha(13),
                  ],
                ),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: currentColor.withAlpha(77),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: currentColor.withAlpha(51),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(77),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: const ColorFilter.mode(
                      Colors.transparent, BlendMode.srcOver),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.1, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: currentMode.value == InputPanelMode.chat
                        ? _buildChatMode(currentColor, darkVariant)
                        : _buildVoiceMemoMode(currentColor, darkVariant),
                  ),
                ),
              ),
            ),

            // Compact language label below panel
            if (showLangLabel)
              AnimatedOpacity(
                opacity: showLangLabel ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 100),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${selectedLang.flag} ${selectedLang.nativeName}',
                    style: TextStyle(
                      fontSize: context.r.sp(11),
                      color: Colors.white.withAlpha(180),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // Expanded Content (Memo Library)
            if (isExpanded.value)
              AnimatedBuilder(
                animation: _expandController,
                builder: (context, child) {
                  return SizeTransition(
                    sizeFactor: _expandController,
                    child: _buildMemoLibrary(),
                  );
                },
              ),
          ],
        ),
      );
    });
  }

  /// Build Chat Input Mode
  Widget _buildChatMode(Color currentColor, Color darkVariant) {
    // Try to get LanguageController safely
    LanguageController? langCtrl;
    try {
      langCtrl = Get.find<LanguageController>();
    } catch (_) {}
    final isDownloading = langCtrl?.isDownloading.value ?? false;

    return Container(
      key: const ValueKey('chat_mode'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mode Switch Button
          _buildModeSwitchButton(currentColor),

          const SizedBox(width: 8),

          // Language flag selector (opens LanguagePickerBottomSheet)
          _buildLanguagePickerButton(langCtrl),

          const SizedBox(width: 8),

          // Expandable Text Input
          Expanded(
            child: _buildExpandableTextInput(currentColor, darkVariant),
          ),

          const SizedBox(width: 10),

          // Mic/Send Button (disabled when downloading)
          IgnorePointer(
            ignoring: isDownloading,
            child: Opacity(
              opacity: isDownloading ? 0.4 : 1.0,
              child: _buildMicOrSendButton(darkVariant),
            ),
          ),

          // Manual Reset Button - appears after voice input is processed
          Obx(() => showResetButton.value
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: _manualReset,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: context.r.scale(44),
                      height: context.r.scale(44),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withAlpha(179),
                            Colors.orange.withAlpha(102),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.orange.withAlpha(204),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withAlpha(77),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: context.r.scale(22),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  /// Build expandable text input that opens in bottom sheet
  Widget _buildExpandableTextInput(Color currentColor, Color darkVariant) {
    return GestureDetector(
      onTap: () => _showExpandedTextInput(currentColor, darkVariant),
      child: Container(
        height: context.r.scale(48),
        decoration: BoxDecoration(
          color: _sttService.isListening.value
              ? Colors.red.withAlpha(25)
              : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _sttService.isListening.value
                ? Colors.red.withAlpha(128)
                : Colors.white.withAlpha(38),
            width: _sttService.isListening.value ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.keyboard,
              color: Colors.grey[500],
              size: context.r.scale(20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() => Text(
                    _textController.text.isEmpty
                        ? (_sttService.isListening.value
                            ? 'Listening...'
                            : 'Type or speak')
                        : _textController.text,
                    style: TextStyle(
                      fontSize: context.r.sp(15),
                      color: _textController.text.isEmpty
                          ? (_sttService.isListening.value
                              ? Colors.red.withAlpha(179)
                              : Colors.white38)
                          : Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
            ),
            Icon(
              Icons.expand_less,
              color: Colors.grey[400],
              size: context.r.scale(20),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  /// Show expanded text input bottom sheet
  void _showExpandedTextInput(Color currentColor, Color darkVariant) {
    if (_sttService.isListening.value) {
      _stopListening();
    }

    try {
      Get.find<OrbThinkingController>().clearAvatar();
    } catch (_) {}

    // Start blinking animation when panel opens for disco-style guidance
    // This helps low-literacy users understand what actions are available
    isClearBlinking.value = true;
    isReadBlinking.value = true;
    isSendBlinking.value = true;

    debugPrint(
        '🎯 [DualModeInputPanel] Started button blinking for user guidance');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(128),
      builder: (context) => _buildExpandedInputSheet(currentColor, darkVariant),
      isDismissible: true,
      enableDrag: true,
    ).then((_) {
      // Stop blinking when panel closes
      isClearBlinking.value = false;
      isReadBlinking.value = false;
      isSendBlinking.value = false;
      debugPrint('🎯 [DualModeInputPanel] Stopped button blinking');
    });
  }

  /// Build the expanded input sheet with glass morphism styling
  Widget _buildExpandedInputSheet(Color currentColor, Color darkVariant) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: MediaQuery.of(context).size.height * 0.65 + bottomPadding,
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
              filter:
                  const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: bottomPadding > 0 ? bottomPadding : 16,
                  ),
                  child: Column(
                    children: [
                      // Handle bar with dynamic color
                      Container(
                        margin: const EdgeInsets.only(top: 16, bottom: 12),
                        width: context.r.scale(48),
                        height: context.r.scale(5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              currentColor.withAlpha(179),
                              currentColor.withAlpha(77),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: currentColor.withAlpha(77),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      // Header with glass styling
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: context.r.symmetric(h: 16, v: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    currentColor.withAlpha(77),
                                    currentColor.withAlpha(38),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: currentColor.withAlpha(128),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: currentColor.withAlpha(51),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_note,
                                    size: context.r.scale(18),
                                    color: currentColor.withAlpha(230),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Enter your message',
                                    style: TextStyle(
                                      fontSize: context.r.sp(15),
                                      fontWeight: FontWeight.w600,
                                      color: currentColor.withAlpha(230),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Close button with glass styling
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withAlpha(51),
                                      Colors.white.withAlpha(26),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: currentColor.withAlpha(102),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: currentColor.withAlpha(51),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: context.r.scale(20),
                                  color: currentColor.withAlpha(230),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider with dynamic color
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              currentColor.withAlpha(128),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Large text input area with glass morphism
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withAlpha(64),
                                  Colors.white.withAlpha(38),
                                  currentColor.withAlpha(26),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: currentColor.withAlpha(128),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: currentColor.withAlpha(51),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.black.withAlpha(26),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: TextField(
                                controller: _textController,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                autofocus: true,
                                style: TextStyle(
                                  fontSize: context.r.sp(18),
                                  height: 1.6,
                                  color: const Color(0xFF230F1F),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type your message here...',
                                  hintStyle: TextStyle(
                                    fontSize: context.r.sp(16),
                                    color: Colors.grey[500],
                                  ),
                                  contentPadding:
                                      EdgeInsets.all(context.r.scale(24)),
                                  border: InputBorder.none,
                                ),
                                scrollPhysics: const BouncingScrollPhysics(),
                                onChanged: (_) => setSheetState(() {}),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Bottom actions with three equally-sized buttons in glass morphism style
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withAlpha(38),
                              Colors.white.withAlpha(13),
                              currentColor.withAlpha(26),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: currentColor.withAlpha(102),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: currentColor.withAlpha(51),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withAlpha(51),
                              blurRadius: 30,
                              spreadRadius: 5,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Clear button - equal width (RED, blinking)
                            Expanded(
                              flex: 1,
                              child: Obx(() => _buildGlassActionButton(
                                    icon: Icons.clear_all,
                                    label: 'Clear',
                                    color: Colors.red,
                                    onTap: () {
                                      _textController.clear();
                                      HapticFeedback.lightImpact();
                                      setSheetState(() {});
                                    },
                                    isBlinking: isClearBlinking.value,
                                  )),
                            ),
                            const SizedBox(width: 10),
                            // Read button - STT reads the text (BLUE, blinking)
                            Expanded(
                              flex: 1,
                              child: Obx(() => _buildGlassActionButton(
                                    icon: Icons.volume_up,
                                    label: 'Read',
                                    color: Colors.blue,
                                    onTap: () {
                                      final text = _textController.text.trim();
                                      if (text.isNotEmpty) {
                                        HapticFeedback.mediumImpact();
                                        SoundService.to.playClick();

                                        // Dismiss the sheet FIRST so TTS can start
                                        // immediately without the sheet blocking the UI.
                                        // _handleReadButton is intentionally NOT awaited
                                        // so playback begins right away in the background.
                                        Navigator.pop(context);
                                        _handleReadButton(text);
                                      }
                                    },
                                    isEnabled:
                                        _textController.text.trim().isNotEmpty,
                                    isBlinking: isReadBlinking.value,
                                  )),
                            ),
                            const SizedBox(width: 10),
                            // Send button - equal width (GREEN, blinking)
                            Expanded(
                              flex: 1,
                              child: Obx(() => _buildGlassActionButton(
                                    icon: Icons.send,
                                    label: 'Send',
                                    color: Colors.green,
                                    onTap: () {
                                      if (_textController.text
                                          .trim()
                                          .isNotEmpty) {
                                        HapticFeedback.mediumImpact();

                                        _sendMessage();
                                        Navigator.pop(context);
                                      }
                                    },
                                    isPrimary: true,
                                    isEnabled:
                                        _textController.text.trim().isNotEmpty,
                                    isBlinking: isSendBlinking.value,
                                  )),
                            ),
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
      },
    );
  }

  /// Build glass morphism action button for the bottom sheet
  Widget _buildGlassActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isEnabled = true,
    bool isBlinking = false,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedBuilder(
        animation: _blinkController,
        builder: (context, child) {
          // Disco-style blink: strong opacity oscillation + scale pulse
          // When blinking, opacity goes from 0.2 to 1.0 to create a flashing effect
          final blinkOpacity =
              isBlinking ? (_blinkController.value * 0.8 + 0.2) : 1.0;

          // Intense shadow spread for disco effect
          final shadowSpread = isBlinking
              ? (_blinkController.value * 8 + 2)
              : (isPrimary ? 3.0 : 1.0);
          final blurRadius = isBlinking
              ? (_blinkController.value * 25 + 10)
              : (isPrimary ? 15.0 : 10.0);

          return Transform.scale(
            // Slight pop effect when blinking
            scale: isBlinking && isEnabled
                ? 1.0 + (_blinkController.value * 0.05)
                : 1.0,
            child: AnimatedContainer(
              duration: const Duration(
                  milliseconds: 50), // Fast updates for disco feel
              padding: context.r.symmetric(h: 6, v: 10),
              decoration: BoxDecoration(
                gradient: isPrimary && isEnabled
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: blinkOpacity),
                          color.withValues(alpha: blinkOpacity * 0.7),
                        ],
                      )
                    : isEnabled
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: blinkOpacity * 0.6),
                              color.withValues(alpha: blinkOpacity * 0.2),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              Colors.grey[300]!.withAlpha(77),
                              Colors.grey[300]!.withAlpha(51),
                            ],
                          ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEnabled
                      ? color.withValues(
                          alpha: isBlinking
                              ? blinkOpacity
                              : (isPrimary ? 0.8 : 0.6))
                      : Colors.grey[400]!.withAlpha(77),
                  width: isBlinking ? 2.5 : (isPrimary ? 2.0 : 1.5),
                ),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: color.withValues(
                              alpha: isBlinking
                                  ? blinkOpacity * 0.7
                                  : (isPrimary ? 0.4 : 0.2)),
                          blurRadius: blurRadius,
                          spreadRadius: shadowSpread,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isPrimary
                          ? (isBlinking
                              ? Colors.white.withValues(alpha: blinkOpacity)
                              : Colors.white)
                          : isEnabled
                              ? color.withValues(
                                  alpha: isBlinking ? blinkOpacity : 0.9)
                              : Colors.grey[400],
                      size: context.r.scale(14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: context.r.sp(12),
                        fontWeight: FontWeight
                            .w800, // Thicker font for better accessibility
                        color: isPrimary
                            ? (isBlinking
                                ? Colors.white.withValues(alpha: blinkOpacity)
                                : Colors.white)
                            : isEnabled
                                ? color.withValues(
                                    alpha: isBlinking ? blinkOpacity : 0.9)
                                : Colors.grey[400],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build Voice Memo Mode
  Widget _buildVoiceMemoMode(Color currentColor, Color darkVariant) {
    return Container(
      key: const ValueKey('voice_memo_mode'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Back Button to return to chat mode
          _buildBackButton(),

          const SizedBox(width: 10),

          // Waveform Visualization
          Expanded(
            child: _buildWaveformVisualization(),
          ),

          const SizedBox(width: 10),

          // Record/Pause/Stop Controls
          _buildRecordingControls(darkVariant),

          const SizedBox(width: 8),

          // Library Button
          _buildLibraryButton(currentColor),
        ],
      ),
    );
  }

  /// Mode switch button (Settings/Gear icon)
  Widget _buildModeSwitchButton(Color currentColor) {
    return GestureDetector(
      onTap: _toggleMode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: context.r.scale(44),
        height: context.r.scale(44),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              currentColor.withAlpha(102),
              currentColor.withAlpha(51),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: currentColor.withAlpha(128),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.settings,
          color: currentColor.withAlpha(230),
          size: context.r.scale(22),
        ),
      ),
    );
  }

  /// Language picker button — opens LanguagePickerBottomSheet
  Widget _buildLanguagePickerButton(LanguageController? langCtrl) {
    if (langCtrl == null) {
      // Fallback to old cycle behavior
      return GestureDetector(
        onTap: _cycleLanguage,
        child: Obx(() => Container(
              width: context.r.scale(44),
              height: context.r.scale(44),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withAlpha(51)),
              ),
              child: Center(
                child: Text(
                  _getLanguageFlag(currentLanguage.value),
                  style: TextStyle(fontSize: context.r.sp(20)),
                ),
              ),
            )),
      );
    }

    return Obx(() {
      final lang = langCtrl.selectedLanguage.value;
      return GestureDetector(
        onTap: () => LanguagePickerBottomSheet.show(context),
        child: Container(
          width: context.r.scale(44),
          height: context.r.scale(44),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withAlpha(51)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(lang.flag, style: TextStyle(fontSize: context.r.sp(18))),
              Icon(Icons.expand_more,
                  size: context.r.scale(10), color: Colors.white54),
            ],
          ),
        ),
      );
    });
  }

  /// Back button for voice memo mode
  Widget _buildBackButton() {
    return GestureDetector(
      onTap: _toggleMode,
      child: Container(
        width: context.r.scale(44),
        height: context.r.scale(44),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(26),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withAlpha(51),
          ),
        ),
        child: Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white70,
          size: context.r.scale(18),
        ),
      ),
    );
  }

  /// Mic or Send button
  Widget _buildMicOrSendButton(Color darkVariant) {
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) {
        return Obx(() {
          final hasText = _textController.text.trim().isNotEmpty;
          final isListening = _sttService.isListening.value;

          // Disco effect for the send button
          final blinkOpacity =
              hasText ? (_blinkController.value * 0.5 + 0.5) : 1.0;
          final shadowSpread = hasText ? (_blinkController.value * 6 + 3) : 3.0;
          final blurRadius =
              hasText ? (_blinkController.value * 20 + 10) : 15.0;

          return GestureDetector(
            onTap: hasText ? _sendMessage : _toggleListening,
            onLongPress: !hasText ? _startVoiceMemoQuick : null,
            child: Transform.scale(
              scale: hasText ? 1.0 + (_blinkController.value * 0.05) : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: context.r.scale(52),
                height: context.r.scale(52),
                decoration: BoxDecoration(
                  gradient: hasText
                      ? LinearGradient(
                          colors: [
                            darkVariant.withValues(alpha: blinkOpacity),
                            darkVariant.withValues(alpha: blinkOpacity * 0.7),
                          ],
                        )
                      : isListening
                          ? const LinearGradient(
                              colors: [Colors.red, Colors.orange],
                            )
                          : LinearGradient(
                              colors: [
                                Colors.white.withAlpha(51),
                                Colors.white.withAlpha(26),
                              ],
                            ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: hasText || isListening
                      ? [
                          BoxShadow(
                            color: (hasText ? darkVariant : Colors.red)
                                .withValues(
                                    alpha: hasText ? blinkOpacity * 0.8 : 0.5),
                            blurRadius: blurRadius,
                            spreadRadius: shadowSpread,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  hasText
                      ? Icons.send
                      : isListening
                          ? Icons.stop
                          : Icons.mic,
                  color: Colors.white,
                  size: context.r.scale(26),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  /// Waveform visualization for voice memo mode
  Widget _buildWaveformVisualization() {
    return Obx(() {
      if (!_memoService.isRecording.value && !_memoService.isPlaying.value) {
        return Container(
          height: context.r.scale(48),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withAlpha(38),
            ),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.r.scale(12)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Tap record to start',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: context.r.sp(14),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        );
      }

      return Container(
        height: context.r.scale(48),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _memoService.isRecording.value
                ? Colors.red.withAlpha(128)
                : Colors.cyanAccent.withAlpha(128),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: _memoService.isRecording.value
              ? _buildRecordingWaveform()
              : _buildPlaybackProgress(),
        ),
      );
    });
  }

  /// Recording waveform
  Widget _buildRecordingWaveform() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, context.r.scale(48)),
          painter: WaveformPainter(
            amplitudes: _memoService.recordingAmplitudes.toList(),
            color: Colors.red,
            animation: _waveformController.value,
          ),
        );
      },
    );
  }

  /// Playback progress bar
  Widget _buildPlaybackProgress() {
    return GestureDetector(
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localOffset = box.globalToLocal(details.globalPosition);
        final percent = (localOffset.dx / box.size.width).clamp(0.0, 1.0);
        final seekPosition = Duration(
          milliseconds:
              (_memoService.playbackDuration.value.inMilliseconds * percent)
                  .round(),
        );
        _memoService.seekTo(seekPosition);
      },
      child: Stack(
        children: [
          // Background
          Container(
            height: context.r.scale(48),
            color: Colors.white.withAlpha(13),
          ),
          // Progress
          Obx(() => FractionallySizedBox(
                widthFactor:
                    _memoService.playbackDuration.value.inMilliseconds > 0
                        ? (_memoService.playbackPosition.value.inMilliseconds /
                                _memoService
                                    .playbackDuration.value.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0,
                child: Container(
                  height: context.r.scale(48),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyanAccent.withAlpha(153),
                        Colors.cyanAccent.withAlpha(51),
                      ],
                    ),
                  ),
                ),
              )),
          // Time display
          Center(
            child: Obx(() => Text(
                  '${_memoService.formatDuration(_memoService.playbackPosition.value)} / ${_memoService.formatDuration(_memoService.playbackDuration.value)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.r.sp(13),
                    fontWeight: FontWeight.w500,
                  ),
                )),
          ),
        ],
      ),
    );
  }

  /// Recording controls (Rec/Pause/Stop)
  Widget _buildRecordingControls(Color darkVariant) {
    return Obx(() {
      if (_memoService.isRecording.value) {
        // Recording in progress - show Pause/Stop
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pause/Resume Button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (_memoService.isPaused.value) {
                  _memoService.resumeRecording();
                } else {
                  _memoService.pauseRecording();
                }
              },
              child: Container(
                width: context.r.scale(44),
                height: context.r.scale(44),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(77),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.orange.withAlpha(153),
                  ),
                ),
                child: Icon(
                  _memoService.isPaused.value ? Icons.play_arrow : Icons.pause,
                  color: Colors.orange,
                  size: context.r.scale(24),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Stop Button
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                final memo = await _memoService.stopRecording();
                if (memo != null) {
                  Get.snackbar(
                    'Voice Memo Saved',
                    'Duration: ${_memoService.formatDuration(memo.duration)}',
                    backgroundColor: Colors.green.withAlpha(230),
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                    snackPosition: SnackPosition.TOP,
                  );
                }
              },
              child: Container(
                width: context.r.scale(48),
                height: context.r.scale(48),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withAlpha(102),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.stop,
                  color: Colors.white,
                  size: context.r.scale(24),
                ),
              ),
            ),
          ],
        );
      } else if (_memoService.isPlaying.value ||
          _memoService.status.value == VoiceMemoStatus.paused) {
        // Playing or paused - show Play/Pause
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (_memoService.status.value == VoiceMemoStatus.playing) {
              _memoService.pausePlayback();
            } else {
              _memoService.resumePlayback();
            }
          },
          child: Container(
            width: context.r.scale(48),
            height: context.r.scale(48),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  darkVariant.withAlpha(230),
                  darkVariant.withAlpha(179),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: darkVariant.withAlpha(102),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _memoService.status.value == VoiceMemoStatus.playing
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.white,
              size: context.r.scale(28),
            ),
          ),
        );
      } else {
        // Not recording - show Rec button
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _memoService.startRecording();
          },
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: context.r.scale(52),
                height: context.r.scale(52),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withAlpha(
                          102 + (_pulseController.value * 77).toInt()),
                      blurRadius: 15,
                      spreadRadius: 3.0 + (_pulseController.value * 3.0),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.fiber_manual_record,
                  color: Colors.white,
                  size: context.r.scale(28),
                ),
              );
            },
          ),
        );
      }
    });
  }

  /// Library button
  Widget _buildLibraryButton(Color currentColor) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showMemoLibrary.toggle();
        if (showMemoLibrary.value) {
          isExpanded.value = true;
          _expandController.forward();
        } else {
          _expandController.reverse().then((_) {
            isExpanded.value = false;
          });
        }
      },
      child: Obx(() => Container(
            width: context.r.scale(44),
            height: context.r.scale(44),
            decoration: BoxDecoration(
              color: showMemoLibrary.value
                  ? currentColor.withAlpha(77)
                  : Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: showMemoLibrary.value
                    ? currentColor.withAlpha(179)
                    : Colors.white.withAlpha(51),
              ),
            ),
            child: Badge(
              isLabelVisible: _memoService.memos.isNotEmpty,
              backgroundColor: currentColor,
              label: Text(
                '${_memoService.memos.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.r.sp(10),
                ),
              ),
              child: Icon(
                Icons.folder_open,
                color: showMemoLibrary.value
                    ? currentColor.withAlpha(230)
                    : Colors.white70,
                size: context.r.scale(22),
              ),
            ),
          )),
    );
  }

  /// Memo library list
  Widget _buildMemoLibrary() {
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 8, right: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(128),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha(26),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Obx(() => _memoService.memos.isEmpty
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(context.r.scale(20)),
                  child: Text(
                    'No voice memos yet',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: context.r.sp(14),
                    ),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: _memoService.memos.length,
                itemBuilder: (context, index) {
                  final memo = _memoService.memos[index];
                  final isPlaying =
                      _memoService.currentMemo.value?.id == memo.id &&
                          _memoService.isPlaying.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? Colors.cyanAccent.withAlpha(26)
                          : Colors.white.withAlpha(13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPlaying
                            ? Colors.cyanAccent.withAlpha(77)
                            : Colors.white.withAlpha(26),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      leading: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: isPlaying ? Colors.cyanAccent : Colors.white70,
                        size: context.r.scale(32),
                      ),
                      title: Text(
                        memo.title ?? 'Voice Memo ${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.r.sp(14),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${_memoService.formatDuration(memo.duration)} • ${_memoService.formatFileSize(memo.fileSize)}',
                        style: TextStyle(
                          color: Colors.white.withAlpha(153),
                          fontSize: context.r.sp(12),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            color: Colors.white70, size: context.r.scale(20)),
                        color: Colors.grey[900],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'play') {
                            _memoService.playMemo(memo);
                          } else if (value == 'rename') {
                            _showRenameDialog(memo);
                          } else if (value == 'delete') {
                            _showDeleteConfirmation(memo);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'play',
                            child: Row(
                              children: [
                                Icon(Icons.play_arrow,
                                    color: Colors.white,
                                    size: context.r.scale(20)),
                                const SizedBox(width: 8),
                                const Text('Play',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit,
                                    color: Colors.white,
                                    size: context.r.scale(20)),
                                const SizedBox(width: 8),
                                const Text('Rename',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete,
                                    color: Colors.red,
                                    size: context.r.scale(20)),
                                const SizedBox(width: 8),
                                const Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (isPlaying) {
                          _memoService.pausePlayback();
                        } else {
                          _memoService.playMemo(memo);
                        }
                      },
                    ),
                  );
                },
              )),
      ),
    );
  }

  /// Show rename dialog
  void _showRenameDialog(VoiceMemo memo) {
    final controller = TextEditingController(text: memo.title);

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Rename Memo',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyanAccent.withAlpha(128)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyanAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _memoService.renameMemo(memo, controller.text);
              }
              Get.back();
            },
            child:
                const Text('Save', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  /// Show delete confirmation
  void _showDeleteConfirmation(VoiceMemo memo) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Delete Memo?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${memo.title ?? 'this memo'}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              _memoService.deleteMemo(memo);
              Get.back();
            },
            child: Text('Delete', style: TextStyle(color: Colors.red[300])),
          ),
        ],
      ),
    );
  }

  /// Send message
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.mediumImpact();

      // Set text in VoiceController so the pipeline can process it
      try {
        final vc = Get.find<VoiceController>();
        vc.textController.text = text;
      } catch (_) {}

      if (widget.onSendMessage != null) {
        widget.onSendMessage!(text);
      }
      _textController.clear();
      textFieldHeight.value = 48.0; // Reset height
      setState(() {});
    }
  }

  /// Handle Read button press - adds message to Voice Chat and triggers TTS with Orb animation
  /// This is NOT treated as an AI query - just reads the text as-is via TTS
  Future<void> _handleReadButton(String text) async {
    try {
      // Use ReadAloudService to handle the read operation
      final readAloudService = Get.find<ReadAloudService>();
      await readAloudService.readText(text: text);

      // Clear the text controller
      _textController.clear();
      textFieldHeight.value = 48.0;
    } catch (e) {
      debugPrint('Error in _handleReadButton: $e');
      // Fallback: just speak the text without adding to chat
      await _ttsService.speak(text);
      _textController.clear();
    }
  }

  /// Toggle listening for STT
  void _toggleListening() {
    if (_sttService.isListening.value) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  /// Start listening with language-specific settings
  void _startListening() async {
    HapticFeedback.mediumImpact();

    try {
      Get.find<OrbThinkingController>().clearAvatar();
    } catch (_) {}

    final success = await UniversalVoicePipeline.to.handleMicTap(
      context: context,
      onUIStartPulse: () {
        _pulseController.repeat(reverse: true);
      },
      onUIStopPulse: () {
        _pulseController.stop();
        showResetButton.value = true;
        setState(() {});
      },
      onPartialText: (text) {
        _textController.text = text;
        setState(() {});
      },
    );

    if (!success) {
      _pulseController.stop();
      showResetButton.value = false;
      setState(() {});
    }
  }

  /// Stop listening
  void _stopListening() {
    HapticFeedback.mediumImpact();
    _sttService.stopListening();
    _pulseController.stop();

    // If there's text, send it
    final text = _textController.text.trim();
    if (text.isNotEmpty && widget.onVoiceInput != null) {
      widget.onVoiceInput!(text);
      showResetButton.value = true;
    }
  }

  /// Quick access to voice memo mode (long press on mic)
  void _startVoiceMemoQuick() {
    HapticFeedback.heavyImpact();
    _toggleMode();
    Future.delayed(const Duration(milliseconds: 100), () {
      _memoService.startRecording();
    });
  }

  /// Manual reset - clears text and shows reset button for next voice input
  void _manualReset() {
    HapticFeedback.mediumImpact();
    _textController.clear();
    showResetButton.value = false;
    textFieldHeight.value = 48.0;
    setState(() {});
    debugPrint(
        '🎯 [DualModeInputPanel] Manual reset completed - ready for next voice input');
  }
}

/// Waveform painter for visualization
class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  final double animation;

  WaveformPainter({
    required this.amplitudes,
    required this.color,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) {
      _drawPlaceholderWaveform(canvas, size);
      return;
    }

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    const barCount = 40;
    final barWidth = width / barCount;
    final spacing = barWidth * 0.3;

    for (int i = 0; i < barCount; i++) {
      final ampIndex = amplitudes.length - barCount + i;
      double amplitude;

      if (ampIndex >= 0 && ampIndex < amplitudes.length) {
        amplitude = amplitudes[ampIndex];
      } else {
        amplitude = (sin((i + animation * 10) * 0.5) + 1) / 2 * 0.3;
      }

      final barHeight = amplitude * height * 0.7;
      final x = i * barWidth + barWidth / 2;

      final barPaint = Paint()
        ..strokeWidth = barWidth - spacing
        ..strokeCap = StrokeCap.round
        ..color = color.withAlpha(102 + (amplitude * 153).toInt());

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        barPaint,
      );
    }
  }

  void _drawPlaceholderWaveform(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(77)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    const barCount = 30;
    final barWidth = width / barCount;

    for (int i = 0; i < barCount; i++) {
      final amplitude = (sin((i + animation * 5) * 0.4) + 1) / 2 * 0.4;
      final barHeight = amplitude * height * 0.5;
      final x = i * barWidth + barWidth / 2;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
