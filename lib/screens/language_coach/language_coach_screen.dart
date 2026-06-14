import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import '../../controllers/language_controller.dart';
import '../../models/language_model.dart';
import '../../services/stt_service.dart';
import '../../services/tts_engine_switcher.dart';
import '../../services/open_router_service.dart';
import '../../services/ai_model_manager.dart';
import '../../widgets/banner_ad_widget.dart';

/// ═══════════════════════════════════════════════════════════════
/// Language Coach Screen — AI-powered pronunciation trainer
/// ═══════════════════════════════════════════════════════════════
///
/// Flow:
/// 1. User selects target language
/// 2. AI gives a sentence in that language
/// 3. User speaks → STT captures it
/// 4. AI analyzes pronunciation errors
/// 5. TTS reads correction in target language using sherpa_onnx
///
/// Unique differentiator: uses native-accent TTS for corrections!
/// ═══════════════════════════════════════════════════════════════
class LanguageCoachScreen extends StatefulWidget {
  const LanguageCoachScreen({super.key});

  static const String routeName = '/language-coach';

  @override
  State<LanguageCoachScreen> createState() => _LanguageCoachScreenState();
}

class _LanguageCoachScreenState extends State<LanguageCoachScreen>
    with TickerProviderStateMixin {
  // Services (all permanent singletons)
  late final LanguageController _langCtrl;
  late final STTService _sttService;
  late final TtsEngineSwitcher _tts;
  late final OpenRouterService _router;
  late final AIModelManager _modelManager;

  // State
  final _isLoading = false.obs;
  final _isListening = false.obs;
  final _isSpeaking = false.obs;
  final _currentSentence = ''.obs;
  final _userSpeech = ''.obs;
  final _feedback = ''.obs;
  final _roundCount = 0.obs;
  final _score = 0.obs;

  // Animation
  late AnimationController _orbAnim;
  late AnimationController _feedbackAnim;
  late Animation<double> _orbScale;
  late Animation<double> _feedbackSlide;

  // Sample sentences per language for round-robin
  static const Map<String, List<String>> _practiceSentences = {
    'fr-FR': [
      'Bonjour, comment allez-vous aujourd\'hui?',
      'Je voudrais une tasse de café, s\'il vous plaît.',
      'Où est la bibliothèque la plus proche?',
    ],
    'de-DE': [
      'Guten Morgen, wie geht es Ihnen?',
      'Ich möchte bitte die Speisekarte sehen.',
      'Wo ist der nächste Bahnhof?',
    ],
    'es-ES': [
      '¿Cómo está usted hoy?',
      'Me gustaría pedir una mesa para dos personas.',
      '¿Dónde está el museo más cercano?',
    ],
    'it-IT': [
      'Buongiorno, come stai?',
      'Vorrei un caffè per favore.',
      'Dov\'è la stazione ferroviaria?',
    ],
    'ja-JP': [
      'おはようございます。今日はいい天気ですね。',
      'すみません、駅はどこですか？',
      'このレストランのおすすめ料理は何ですか？',
    ],
    'zh-CN': [
      '你好，请问你叫什么名字？',
      '我想要一杯咖啡，谢谢。',
      '这里最近的地铁站在哪里？',
    ],
    'hi-IN': [
      'नमस्ते, आप कैसे हैं?',
      'मुझे एक कप चाय चाहिए।',
      'यहाँ से रेलवे स्टेशन कितनी दूर है?',
    ],
    'ar-SA': [
      'مرحباً، كيف حالك اليوم؟',
      'أريد فنجان قهوة من فضلك.',
      'أين أقرب محطة مترو؟',
    ],
  };

  @override
  void initState() {
    super.initState();
    _langCtrl = Get.find<LanguageController>();
    _sttService = Get.find<STTService>();
    _tts = Get.find<TtsEngineSwitcher>();
    _router = Get.find<OpenRouterService>();
    _modelManager = Get.find<AIModelManager>();

    _orbAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _feedbackAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _orbScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _orbAnim, curve: Curves.easeInOut),
    );

    _feedbackSlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _feedbackAnim, curve: Curves.easeOut),
    );

    // Start first round
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNewRound());
  }

  @override
  void dispose() {
    _orbAnim.dispose();
    _feedbackAnim.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // Core Logic
  // ═══════════════════════════════════════════════════════════

  Future<void> _startNewRound() async {
    _isLoading.value = true;
    _feedback.value = '';
    _userSpeech.value = '';
    _feedbackAnim.reset();

    final lang = _langCtrl.selectedLanguage.value;

    // Try fixed sentences first, then AI-generated
    final fixed = _practiceSentences[lang.sttLocale];
    if (fixed != null && fixed.isNotEmpty) {
      final idx = _roundCount.value % fixed.length;
      _currentSentence.value = fixed[idx];
      _isLoading.value = false;
    } else {
      // Ask AI to generate a practice sentence
      await _generateSentence(lang);
    }

    // Speak the sentence in target language
    await _speakSentence(_currentSentence.value);
  }

  Future<void> _generateSentence(LanguageModel lang) async {
    try {
      final route = _modelManager.routeQuery('language practice');
      final result = await _router.generateResponse(
        route: route,
        systemPrompt:
            'You are a language teacher. Generate ONE simple, practical sentence '
            'in ${lang.name} for beginner language learners to practice pronunciation. '
            'Reply with ONLY the sentence, no translation, no explanation.',
        userMessage: 'Give me a practice sentence in ${lang.name}',
      );
      _currentSentence.value = result?.trim() ?? 'Hello, how are you today?';
    } catch (e) {
      _currentSentence.value = 'Hello, how are you today?';
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _speakSentence(String text) async {
    _isSpeaking.value = true;
    try {
      await _tts.speak(text);
    } finally {
      _isSpeaking.value = false;
    }
  }

  Future<void> _startListening() async {
    if (_isListening.value) {
      await _stopListening();
      return;
    }
    _isListening.value = true;
    _userSpeech.value = '';
    _feedback.value = '';

    final lang = _langCtrl.selectedLanguage.value;

    // Set locale for this language before listening
    await _sttService.setLocaleFromLanguageCode(lang.sttLocale);

    await _sttService.startListening(
      onResult: (text) {
        _userSpeech.value = text;
      },
    );

    // Auto-stop after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (_isListening.value) _stopListening();
    });
  }

  Future<void> _stopListening() async {
    await _sttService.stopListening();
    _isListening.value = false;
    if (_userSpeech.value.isNotEmpty) {
      await _analyzePronunciation();
    }
  }

  Future<void> _analyzePronunciation() async {
    _isLoading.value = true;
    try {
      final lang = _langCtrl.selectedLanguage.value;
      final route = _modelManager.routeQuery('pronunciation feedback');

      final prompt = '''
You are a strict but encouraging language pronunciation coach for ${lang.name}.

The student was asked to say:
"${_currentSentence.value}"

The speech recognition captured:
"${_userSpeech.value}"

Analyze the differences and provide:
1. A percentage score (0-100) for how well they did
2. Specific pronunciation errors (if any)
3. The corrected, clear version they should aim for
4. One encouraging tip

Format:
SCORE: [number]
ERRORS: [list of errors, or "None!" if perfect]
CORRECTION: [the sentence written phonetically or with stress marks]
TIP: [one short tip]

Keep response concise and supportive. No markdown, plain text only.
''';

      final result = await _router.generateResponse(
        route: route,
        systemPrompt:
            'You are a language pronunciation coach. Be concise and encouraging.',
        userMessage: prompt,
      );

      if (result != null) {
        _feedback.value = result.trim();

        // Extract score
        final scoreMatch = RegExp(r'SCORE:\s*(\d+)').firstMatch(result);
        if (scoreMatch != null) {
          final s = int.tryParse(scoreMatch.group(1) ?? '0') ?? 0;
          _score.value = ((_score.value * _roundCount.value + s) ~/
              (_roundCount.value + 1));
        }

        _roundCount.value++;

        // Animate feedback card
        _feedbackAnim.forward();

        // Speak the correction in target language
        final correctionMatch =
            RegExp(r'CORRECTION:\s*(.+)', multiLine: true).firstMatch(result);
        if (correctionMatch != null) {
          await Future.delayed(const Duration(milliseconds: 800));
          await _speakSentence(correctionMatch.group(1)!.trim());
        }
      }
    } catch (e) {
      _feedback.value = 'Analysis failed. Try again!';
    } finally {
      _isLoading.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Get.back(),
        ),
        title: Obx(() {
          final lang = _langCtrl.selectedLanguage.value;
          return Row(
            children: [
              Text(lang.flag, style: TextStyle(fontSize: context.r.sp(22))),
              const RSizedBox(w: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      'Language Coach',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.r.sp(16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      lang.name,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: context.r.sp(11),
                      ),
                    ),
                ],
              ),
            ],
          );
        }),
        actions: [
          // Score chip
          Obx(() => _roundCount.value > 0
              ? Container(
                  margin: EdgeInsets.only(right: context.r.scale(16)),
                  padding:
                      context.r.symmetric(h: 12, v: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(30),
            borderRadius: BorderRadius.circular(context.r.scale(20)),
                    border: Border.all(color: Colors.amber.withAlpha(100)),
                  ),
                  child: Text(
                    '⭐ ${_score.value}%',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: context.r.sp(13),
                    ),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Practice sentence card ───────────────────────────────
            _buildSentenceCard(),

            const Spacer(),

            // ── Orb / Mic area ───────────────────────────────────────
            _buildMicOrb(),

            const RSizedBox(h: 24),

            // ── Control buttons ──────────────────────────────────────
            _buildControls(),

            const RSizedBox(h: 16),

            // ── User speech capture ──────────────────────────────────
            _buildUserSpeechBubble(),

            // ── Feedback card ────────────────────────────────────────
            _buildFeedbackCard(),

            const RSizedBox(h: 16),

            // ── Banner Ad ────────────────────────────────────────
            const Center(child: BannerAdWidget()),
            const RSizedBox(h: 24),

          ],
        ),
      ),
    );
  }

  Widget _buildSentenceCard() {
    return Obx(() {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: EdgeInsets.fromLTRB(context.r.scale(16), context.r.scale(8), context.r.scale(16), 0),
        padding: context.r.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1A2332),
              Color(0xFF0D1117),
            ],
          ),
          borderRadius: BorderRadius.circular(context.r.scale(20)),
          border: Border.all(
            color: Colors.blue.withAlpha(80),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.record_voice_over,
                    color: Colors.blue, size: context.r.scale(16)),
                const RSizedBox(w: 8),
                Text(
                  'Say this:',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: context.r.sp(12),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                // Replay button
                GestureDetector(
                  onTap: _isSpeaking.value || _isLoading.value
                      ? null
                      : () => _speakSentence(_currentSentence.value),
                  child: Icon(
                    Icons.replay,
                    color: _isSpeaking.value ? Colors.blue : Colors.white38,
                    size: context.r.scale(18),
                  ),
                ),
              ],
            ),
            const RSizedBox(h: 12),
            _isLoading.value && _currentSentence.value.isEmpty
                ? const CircularProgressIndicator(
                    color: Colors.blue,
                    strokeWidth: 2,
                  )
                : Text(
                    _currentSentence.value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.r.sp(20),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
            const RSizedBox(h: 8),
            Text(
              'Round ${_roundCount.value + 1}',
              style: TextStyle(color: Colors.white30, fontSize: context.r.sp(11)),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMicOrb() {
    return Obx(() {
      final isActive = _isListening.value;
      final color = isActive ? Colors.red : Colors.blue;

      return AnimatedBuilder(
        animation: _orbAnim,
        builder: (context, child) {
          final scale = isActive ? _orbScale.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: _isLoading.value ? null : _startListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: context.r.scale(90),
                height: context.r.scale(90),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withAlpha(200),
                      color.withAlpha(80),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(isActive ? 150 : 80),
                      blurRadius: isActive ? 30 : 15,
                      spreadRadius: isActive ? 8 : 2,
                    ),
                  ],
                ),
                child: Icon(
                  isActive ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: context.r.scale(36),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildControls() {
    return Obx(() => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Repeat sentence button
            _buildControlBtn(
              icon: Icons.volume_up,
              label: 'Repeat',
              color: Colors.blue,
              onTap: _isSpeaking.value || _isLoading.value
                  ? null
                  : () => _speakSentence(_currentSentence.value),
            ),
              const RSizedBox(w: 16),
            // Next sentence button
            _buildControlBtn(
              icon: Icons.skip_next,
              label: 'Next',
              color: Colors.green,
              onTap: _isLoading.value ? null : _startNewRound,
            ),
          ],
        ));
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: context.r.symmetric(h: 20, v: 10),
        decoration: BoxDecoration(
          color: (onTap == null ? Colors.grey : color).withAlpha(30),
          borderRadius: BorderRadius.circular(context.r.scale(20)),
          border: Border.all(
            color: (onTap == null ? Colors.grey : color).withAlpha(100),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: onTap == null ? Colors.grey : color, size: context.r.scale(16)),
            const RSizedBox(w: 6),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.grey : color,
                fontSize: context.r.sp(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSpeechBubble() {
    return Obx(() {
      if (_userSpeech.value.isEmpty && !_isListening.value) {
        return const RSizedBox(h: 8);
      }
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: context.r.symmetric(h: 16, v: 8),
        padding: context.r.symmetric(h: 16, v: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(context.r.scale(16)),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          children: [
            Icon(
              _isListening.value ? Icons.mic : Icons.person,
              color: _isListening.value ? Colors.red : Colors.white54,
              size: context.r.scale(16),
            ),
            const RSizedBox(w: 10),
            Expanded(
              child: Text(
                _isListening.value
                    ? (_userSpeech.value.isEmpty
                        ? 'Listening…'
                        : _userSpeech.value)
                    : _userSpeech.value,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: context.r.sp(13),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ), // close Expanded
            ],
        ),
      );
    });
  }

  Widget _buildFeedbackCard() {
    return Obx(() {
      if (_feedback.value.isEmpty) return const SizedBox.shrink();

      return AnimatedBuilder(
        animation: _feedbackAnim,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _feedbackSlide.value),
            child: Opacity(
              opacity: _feedbackAnim.value,
              child: child,
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.fromLTRB(context.r.scale(16), 0, context.r.scale(16), 0),
          padding: context.r.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1A3320),
                Color(0xFF0D1117),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.green.withAlpha(80),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school, color: Colors.green, size: context.r.scale(16)),
                  const RSizedBox(w: 8),
                  Text(
                    'COACH FEEDBACK',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: context.r.sp(11),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoading.value)
                    const RSizedBox(
                      w: 14,
                      h: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
              const RSizedBox(h: 10),
              Text(
                _feedback.value,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: context.r.sp(13),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
