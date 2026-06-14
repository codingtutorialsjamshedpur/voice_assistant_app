import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../shared/theme/responsive.dart';
import '../controllers/language_controller.dart';
import '../controllers/voice_preview_controller.dart';
import '../models/language_model.dart';
import '../services/tts_engine_switcher.dart';
import '../shared/controllers/top_panel_controller.dart';
import 'model_download_dialog.dart';

/// Language selection bottom sheet
///
/// Shows all languages in 3 collapsible sections.
/// Handles download-required languages with a prompt chip.
class LanguagePickerBottomSheet extends StatefulWidget {
  const LanguagePickerBottomSheet({super.key});

  /// Show the bottom sheet
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor:
          Colors.black.withAlpha(128), // Matches dual_mode_input_panel barrier
      builder: (_) => const LanguagePickerBottomSheet(),
    );
  }

  @override
  State<LanguagePickerBottomSheet> createState() =>
      _LanguagePickerBottomSheetState();
}

class _LanguagePickerBottomSheetState extends State<LanguagePickerBottomSheet> {
  final LanguageController _langCtrl = Get.find<LanguageController>();
  final TopPanelController _topPanelCtrl = Get.find<TopPanelController>();

  final TextEditingController _searchCtrl = TextEditingController();
  final RxString _query = ''.obs;
  late final VoicePreviewController _previewCtrl;

  // Collapsible section states
  final RxBool _mainExpanded = true.obs;
  final RxBool _indianExpanded = true.obs;
  final RxBool _intlExpanded = true.obs;

  @override
  void initState() {
    super.initState();
    _previewCtrl = Get.put(VoicePreviewController());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    Get.delete<VoicePreviewController>();
    super.dispose();
  }

  List<LanguageModel> _filter(List<LanguageModel> langs) {
    final q = _query.value.toLowerCase().trim();
    if (q.isEmpty) return langs;
    return langs
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            l.nativeName.toLowerCase().contains(q))
        .toList();
  }

  /// FIX 1: Read aloud the selected language with TTS
  Future<void> _speakLanguageSelection(LanguageModel lang) async {
    try {
      // Construct message: "Hello, hi, you have selected [Language]"
      String selectionMessage = 'Hello, hi, you have selected ${lang.name}';

      // ACCENT FIX: native script versions
      if (lang.code == 'or') {
        selectionMessage =
            'ନମସ୍କାର, ଆପଣ ଓଡିଆ ଚୟନ କରିଛନ୍ତି'; // Hello, you selected Odia
      } else if (lang.code == 'as') {
        selectionMessage =
            'নমস্কাৰ, আপুনি অসমীয়া বাছনি কৰিছে'; // Hello, you selected Assamese
      } else if (lang.code == 'mai') {
        selectionMessage =
            'नमस्ते, अहाँ मैथिली चुनने छी'; // Hello, you selected Maithili
      } else if (lang.code == 'hi' || lang.code == 'hinglish') {
        selectionMessage =
            'नमस्ते, आपने हिंदी चुनी है'; // Hello, you selected Hindi
      } else if (lang.code == 'bn') {
        selectionMessage =
            'নমস্কার, আপনি বাংলা বেছে নিয়েছেন'; // Hello, you selected Bengali
      }

      debugPrint(
          '🔊 [LanguagePicker] Speaking selection: $selectionMessage (${lang.code}) using engine: ${lang.ttsEngine.name}');

      // Use TtsEngineSwitcher if available to speak in the selected language
      // Otherwise use basic TTS service
      try {
        final engineSwitcher = Get.find<TtsEngineSwitcher>();
        // Pass the language code to ensure correct accent/voice is used
        await engineSwitcher.speakInLanguage(selectionMessage, lang.sttLocale);
        debugPrint('✅ [LanguagePicker] Successfully spoke: $selectionMessage');
      } catch (e) {
        debugPrint('⚠️ [LanguagePicker] TtsEngineSwitcher error: $e');
        // Fallback: use basic TTS if engine switcher not available
        // The language has been switched by selectLanguage(), so TTS should use it
        await Future.delayed(const Duration(milliseconds: 300));
        // No direct service available here, but selectLanguage() has already
        // notified the TtsEngineSwitcher, so the next TTS call will use the new language
      }
    } catch (e) {
      debugPrint('❌ [LanguagePicker] Error speaking language selection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Obx(() {
          final currentColor = _topPanelCtrl.currentColor;
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              // RepaintBoundary isolates this sheet's rasterization from the
              // AppBackground layer so the backdrop filter does not force a
              // full scene re-rasterization that causes the wallpaper flicker.
              child: RepaintBoundary(
                child: BackdropFilter(
                  // Real glassmorphism blur — matches the Save Audio bottom sheet
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // ── Handle bar ───────────────────────────────────────────────
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            width: context.r.scale(40),
                            height: context.r.scale(4),
                            decoration: BoxDecoration(
                              // Tinted with theme color for full visual consistency
                              color: currentColor.withAlpha(160),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // ── Title ────────────────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Icon(Icons.language, color: accent, size: context.r.scale(22)),
                              const SizedBox(width: 10),
                              Text(
                                'Select Language',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),

                        // ── Search bar ───────────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Search languages…',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onChanged: (v) => _query.value = v,
                          ),
                        ),

                        // ── Download prompt chip ──────────────────────────────────────
                        Obx(() {
                          final pending = _langCtrl.pendingLanguage.value;
                          if (pending == null ||
                              !_langCtrl.showDownloadPrompt.value) {
                            return const SizedBox.shrink();
                          }
                          final voice = pending.voices.isNotEmpty
                              ? pending.voices.first
                              : null;
                          final sizeMB = voice?.sizeMB ?? 0;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: accent.withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: accent.withAlpha(120)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '📥 ${pending.flag} ${pending.nativeName} needs download'
                                  '${sizeMB > 0 ? ' (${sizeMB}MB)' : ''}',
                                  style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ModelDownloadDialog.show(pending);
                                  },
                                  child: const Text('Download & Select'),
                                ),
                                GestureDetector(
                                  onTap: _langCtrl.cancelDownload,
                                  child: Icon(Icons.close, size: context.r.scale(18)),
                                ),
                              ],
                            ),
                          );
                        }),

                        // ── Language list ────────────────────────────────────────────
                        Expanded(
                          child: Obx(() {
                            final main = _filter(_langCtrl.mainLanguages);
                            final indian =
                                _filter(_langCtrl.nativeIndianLanguages);
                            final intl =
                                _filter(_langCtrl.internationalLanguages);

                            return ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.only(bottom: 32),
                              children: [
                                _buildSection(
                                  'MAIN',
                                  main,
                                  _mainExpanded,
                                  accent,
                                ),
                                _buildSection(
                                  'NATIVE INDIAN',
                                  indian,
                                  _indianExpanded,
                                  const Color(0xFFFF9933),
                                ),
                                _buildSection(
                                  'INTERNATIONAL',
                                  intl,
                                  _intlExpanded,
                                  Colors.blueAccent,
                                ),
                              ],
                            );
                          }),
                        ), // Expanded
                      ], // Column children
                    ), // Column
                  ), // SafeArea
                ), // BackdropFilter
              ), // RepaintBoundary
            ), // ClipRRect
          ); // AnimatedContainer
        }); // Obx
      }, // Builder
    ); // DraggableScrollableSheet
  } // build

  Widget _buildSection(
    String title,
    List<LanguageModel> langs,
    RxBool expanded,
    Color color,
  ) {
    if (langs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        InkWell(
          onTap: () => expanded.value = !expanded.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: context.r.scale(4),
                  height: context.r.scale(16),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: context.r.sp(12),
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Obx(() => Icon(
                      expanded.value ? Icons.expand_less : Icons.expand_more,
                      color: color,
                      size: context.r.scale(20),
                    )),
              ],
            ),
          ),
        ),

        // Grid of language cards
        Obx(() => AnimatedCrossFade(
              firstChild: _buildLanguageGrid(langs, color),
              secondChild: const SizedBox.shrink(),
              crossFadeState: expanded.value
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
            )),

        Divider(color: Colors.grey.withAlpha(40), height: 1),
      ],
    );
  }

  Widget _buildLanguageGrid(List<LanguageModel> langs, Color sectionColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: langs
            .map((lang) => _buildLanguageCard(lang, sectionColor))
            .toList(),
      ),
    );
  }

  Widget _buildLanguageCard(LanguageModel lang, Color sectionColor) {
    return Obx(() {
      final isSelected = _langCtrl.selectedLanguage.value.code == lang.code;
      final isDownloaded = _langCtrl.isDownloaded(lang);
      final isPreviewPlaying = _previewCtrl.isPreviewPlaying.value &&
          _previewCtrl.previewingVoiceId.value ==
              (lang.voices.isNotEmpty ? lang.voices.first.id : '');
      final theme = Theme.of(context);
      final canPreview = lang.ttsEngine != TTSEngine.flutterTts &&
          lang.voices.isNotEmpty &&
          isDownloaded;

      return GestureDetector(
        onTap: () async {
          // FIX: Wait for language selection to complete before speaking
          await _langCtrl.selectLanguage(lang);

          // If switch succeeded (no pending download), close sheet and speak
          if (!_langCtrl.showDownloadPrompt.value &&
              _langCtrl.selectedLanguage.value.code == lang.code) {
            // Small delay to ensure TTS engine is fully configured
            await Future.delayed(const Duration(milliseconds: 200));

            // FIX 1: Read aloud the selected language with TTS
            await _speakLanguageSelection(lang);

            if (mounted) Navigator.pop(context);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: context.r.scale(100),
          height: context.r.scale(100),
          decoration: BoxDecoration(
            color: isSelected
                ? sectionColor.withAlpha(30)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? sectionColor : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: sectionColor.withAlpha(60),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Stack(
            children: [
              // Main content
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(lang.flag, style: TextStyle(fontSize: context.r.sp(28))),
                    const SizedBox(height: 4),
                    Text(
                      lang.nativeName,
                      style: TextStyle(
                        fontSize: context.r.sp(11),
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? sectionColor
                            : theme.textTheme.bodyMedium?.color,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lang.nativeName != lang.name)
                      Text(
                        lang.name,
                        style: TextStyle(fontSize: context.r.sp(9), color: theme.hintColor),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    // Preview button row
                    _buildPreviewButton(lang, canPreview, isPreviewPlaying),
                  ],
                ),
              ),

              // Download status indicator (top-right corner)
              Positioned(
                top: 5,
                right: 5,
                child: _buildDownloadIndicator(lang, isDownloaded),
              ),

              // Selected checkmark (top-left corner)
              if (isSelected)
                Positioned(
                  top: 5,
                  left: 5,
                  child:
                      Icon(Icons.check_circle, size: context.r.scale(13), color: sectionColor),
                ),
            ],
          ),
        ),
      );
    });
  }

  /// Preview play/stop button
  Widget _buildPreviewButton(
      LanguageModel lang, bool canPreview, bool isPlaying) {
    if (lang.ttsEngine == TTSEngine.flutterTts) {
      return SizedBox(height: context.r.scale(18));
    }
    if (!canPreview) {
      // Not downloaded — show tooltip hint
      return Tooltip(
        message: 'Download to preview',
        child:
            Icon(Icons.volume_off, size: context.r.scale(13), color: Colors.grey.withAlpha(120)),
      );
    }
    return GestureDetector(
      onTap: () async {
        if (isPlaying) {
          await _previewCtrl.stopPreview();
        } else {
          await _previewCtrl.previewVoice(lang.voices.first, lang.name);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isPlaying ? Icons.stop_circle : Icons.play_circle_outline,
          key: ValueKey(isPlaying),
          size: context.r.scale(16),
          color: isPlaying ? Colors.red : Colors.green,
        ),
      ),
    );
  }

  Widget _buildDownloadIndicator(LanguageModel lang, bool isDownloaded) {
    if (lang.ttsEngine == TTSEngine.flutterTts) {
      // System voice — always available
      return const SizedBox.shrink();
    }
    if (lang.voices.isEmpty) {
      return const SizedBox.shrink();
    }
    if (isDownloaded) {
      return Container(
        width: context.r.scale(10),
        height: context.r.scale(10),
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      );
    }
    return Icon(Icons.cloud_download_outlined,
        size: context.r.scale(14), color: Colors.grey);
  }
}
