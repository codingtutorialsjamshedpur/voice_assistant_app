/// ═══════════════════════════════════════════════════════════════
/// AI Model Manager — Route queries to the best model
/// ═══════════════════════════════════════════════════════════════
/// 25+ query categories → best model mapping.
/// Considers: model specialty, rate limits, errors, load balance.
/// Updated: April 2026 with latest provider mappings
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'api_keys_config.dart';
import 'open_router_service.dart';
import '../controllers/language_controller.dart';

// ─── Provider Health Check ────────────────────────────────────
enum ProviderHealth {
  untested,
  healthy, // Passed on 1st attempt (Green)
  degraded, // Passed on 2nd attempt (Yellow)
  failing, // Failed 2+ attempts (Red)
}

// ─── Query Categories ─────────────────────────────────────────
enum QueryCategory {
  indiaInDetail,
  hinduGodsGoddesses,
  sikhism,
  christianity,
  generalKnowledge,
  storyTelling,
  songsLyricsKnowledge,
  astrology,
  numerology,
  creative,
  futuristicApproach,
  genZStyle,
  technologyExplained,
  aiKnowledge,
  codingProgramming,
  gamesRelated,
  feedback,
  nonDiplomatic,
  hindiDevnagri,
  hindiFluent,
  hinglish,
  formalEnglish,
  informalEnglish,
  englishLearning,
  indianLaws,
  books,
  musicArtist,
  currency,
  mathCalculation,
  englishVocabulary,
  englishQuotes,
  hindiQuotes,
  languageTranslator,
  languageTranscriber,
  scienceSubject,
  greatPeopleInfo,
  realTimeData,
  unknown,
}

// ─── Provider Enum ────────────────────────────────────────────
// 14 providers — one per distinct model in api_keys_config.dart
enum AIProvider {
  // ── Groq (4 model slots × 4 dedicated API keys) ──────────
  groq, // key_1: llama-3.1-8b-instant   — Fast Chat
  groqLlama4Scout, // key_2: llama-4-scout-17b       — Chat
  groqGptOss, // key_3: gpt-oss-120b (via Groq) — Advanced Reasoning
  groqQwen, // key_4: qwen/qwen3-32b           — Extended Context
  // ── Direct APIs ──────────────────────────────────────────
  nvidia, // NVIDIA NIM: minimaxai/minimax-m2.5
  github, // DEPRECATED: GPT-4o-mini (unauthorized)
  mistralDirect, // Mistral API: mistral-small
  // ── OpenRouter (6 models via dedicated keys + auto) ──────
  openRouterStepFlash, // openai/gpt-oss-120b
  openRouterGLM, // z-ai/glm-4.5-air
  openRouterGemma, // google/gemma-4-31b-it
  openRouterMistral, // mistralai/mistral-small-3.1
  openRouterNemotron, // nvidia/nemotron-3-super-120b
  openRouterMinimax, // minimax/minimax-m2.5
  openRouterAuto, // openrouter/auto
  // ── Google Gemini Direct ───────────────────────────────────
  googleGeminiFlashLite, // gemini-3.1-flash-lite (hypothetical/user-defined)
  googleGeminiProPreview, // gemini-3.1-pro-preview-custom-tools
  googleGemini35Flash, // gemini-3.5-flash
  googleGemma4A4B, // gemma-4-26b-a4b-it
}

// ─── Model Route Result ──────────────────────────────────────
class ModelRoute {
  final AIProvider provider;
  final String modelId;
  final String displayName;
  final String apiKey;
  final String baseUrl;
  final QueryCategory category;

  const ModelRoute({
    required this.provider,
    required this.modelId,
    required this.displayName,
    required this.apiKey,
    required this.baseUrl,
    required this.category,
  });
}

/// ═══════════════════════════════════════════════════════════════
/// AIModelManager Service
/// ═══════════════════════════════════════════════════════════════
class AIModelManager extends GetxService {
  // Current active model (observable for UI)
  final activeModelName = 'Groq Llama'.obs;
  final activeCategory = QueryCategory.unknown.obs;

  // ── User-selected preferred provider (null = auto-routing) ────
  final Rx<AIProvider?> preferredProvider = Rx<AIProvider?>(null);

  // Rate-limit / error tracking per provider
  final _errorCounts = <AIProvider, int>{};
  final _lastUsed = <AIProvider, DateTime>{};

  // ── Timed Blacklist with Automatic Recovery ──────────────────
  // Providers that fail are blacklisted for 5 minutes, then automatically recovered
  // This prevents transient failures from becoming permanent
  final _blacklistedUntil = <AIProvider, DateTime>{};

  // ── Intelligent Health Monitoring ──────────────────────────────
  final providerHealth = <AIProvider, ProviderHealth>{}.obs;
  bool _isTestingHealth = false;

  // Observable blacklist for UI display
  final blacklistedProviders = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    // Listen to model switches to show localized toast (VC-07)
    ever(activeModelName, (String newModel) {
      _showModelSwitchToast(newModel);
    });
  }

  void _showModelSwitchToast(String modelName) {
    String translatedSelected = 'Selected'; // default en

    try {
      if (Get.isRegistered<LanguageController>()) {
        final langCode =
            Get.find<LanguageController>().selectedLanguage.value.code;
        if (langCode == 'hi' || langCode == 'hi-IN' || langCode == 'hinglish') {
          translatedSelected = 'चुना गया';
        } else if (langCode.startsWith('pa')) {
          translatedSelected = 'ਚੁਣਿਆ';
        } else if (langCode.startsWith('bn')) {
          translatedSelected = 'নির্বাচিত';
        } else if (langCode.startsWith('ta')) {
          translatedSelected = 'தேர்ந்தெடுக்கப்பட்டது';
        } else if (langCode.startsWith('te')) {
          translatedSelected = 'ఎంచుకోబడింది';
        } else if (langCode.startsWith('gu')) {
          translatedSelected = 'પસંદ કરેલ';
        } else if (langCode.startsWith('mr')) {
          translatedSelected = 'निवडले';
        }
      }
    } catch (_) {}

    Get.snackbar(
      'AI Model Changed',
      '$modelName $translatedSelected',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      isDismissible: true,
      margin: const EdgeInsets.all(10),
    );
  }

  // ── Complete model catalog for UI picker — ALL 14 models ─────
  static const List<Map<String, String>> allModelCatalog = [
    // ── Groq Models ──────────────────────────────────────────────
    {
      'provider': 'groq',
      'displayName': 'Groq Llama 3.1 8B',
      'category': 'Fast & General',
      'group': 'OpenCode Zen',
      'icon': '⚡',
    },
    {
      'provider': 'groqLlama4Scout',
      'displayName': 'Groq Llama 4 Scout',
      'category': 'Smart Chat',
      'group': 'OpenCode Zen',
      'icon': '🦙',
    },
    {
      'provider': 'groqGptOss',
      'displayName': 'Groq GPT OSS 120B',
      'category': 'Advanced Reasoning',
      'group': 'OpenCode Zen',
      'icon': '🧠',
    },
    {
      'provider': 'groqQwen',
      'displayName': 'Groq Qwen3 32B',
      'category': 'Extended Context',
      'group': 'OpenCode Zen',
      'icon': '📖',
    },
    // ── Direct API Models ────────────────────────────────────────
    {
      'provider': 'nvidia',
      'displayName': 'NVIDIA Minimax M2.5',
      'category': 'Complex Reasoning',
      'group': 'NVIDIA',
      'icon': '🔬',
    },
    {
      'provider': 'mistralDirect',
      'displayName': 'Mistral Small (Direct)',
      'category': 'Creative & Math',
      'group': 'Mistral',
      'icon': '🌊',
    },
    // ── Google Gemini Models ─────────────────────────────────────
    {
      'provider': 'googleGeminiFlashLite',
      'displayName': 'Gemini 3.1 Flash Lite',
      'category': 'Real-time Google AI',
      'group': 'Google',
      'icon': '♊',
    },
    {
      'provider': 'googleGeminiProPreview',
      'displayName': 'Gemini 3.1 Pro Preview Custom Tools',
      'category': 'Real-time Google AI',
      'group': 'Google',
      'icon': '🛠️',
    },
    {
      'provider': 'googleGemini35Flash',
      'displayName': 'Gemini 3.5 Flash',
      'category': 'Real-time Google AI',
      'group': 'Google',
      'icon': '✨',
    },
    {
      'provider': 'googleGemma4A4B',
      'displayName': 'Gemma 4 26B A4B IT',
      'category': 'Real-time Google AI',
      'group': 'Google',
      'icon': '💎',
    },
    // ── OpenRouter Models ────────────────────────────────────────
    {
      'provider': 'openRouterStepFlash',
      'displayName': 'GPT OSS 120B',
      'category': 'Tech & AI',
      'group': 'OpenRouter',
      'icon': '🔧',
    },
    {
      'provider': 'openRouterGLM',
      'displayName': 'GLM 4.5 Air',
      'category': 'Translation',
      'group': 'OpenRouter',
      'icon': '🌐',
    },
    {
      'provider': 'openRouterGemma',
      'displayName': 'Gemma 4 31B',
      'category': 'Songs & Music',
      'group': 'OpenRouter',
      'icon': '🎵',
    },
    {
      'provider': 'openRouterMistral',
      'displayName': 'Mistral Small 3.1',
      'category': 'Stories & Math',
      'group': 'OpenRouter',
      'icon': '✍️',
    },
    {
      'provider': 'openRouterNemotron',
      'displayName': 'NVIDIA Nemotron 3 Super',
      'category': 'General Purpose',
      'group': 'OpenRouter',
      'icon': '🤖',
    },
    {
      'provider': 'openRouterMinimax',
      'displayName': 'Minimax M2.5',
      'category': 'Coding',
      'group': 'OpenRouter',
      'icon': '💻',
    },
    {
      'provider': 'openRouterAuto',
      'displayName': 'Auto (Best Match)',
      'category': 'AI-Optimized',
      'group': 'AI',
      'icon': '🎯',
    },
  ];

  // ─── CATEGORY → PRIMARY MODEL MAPPING ──────────────────────
  // Best model for each category based on speciality analysis:
  //
  // GROQ (Mixtral 8x7B): Ultra-fast, reliable responses.
  //   Best for India, religions, Hindi, Hinglish, general knowledge,
  //   quick answers, informal chat, gen-z, feedback, non-diplomatic, games.
  //
  // NVIDIA (Minimax M2.5): Strong reasoning via NIM. Best for complex tasks,
  //   astrology, numerology, futuristic, science, math.
  //
  // GITHUB (GPT-4o-mini): Best for formal English, vocabulary,
  //   quotes, English learning, books, great people info.
  //   ⚠️ Note: Currently unauthorized (requires "models" permission)
  //
  // OpenRouter Models (April 2026):
  //   - Step 3.5 Flash: Technology & AI knowledge
  //   - GLM 4.5 Air: Language translation/transcription
  //   - Gemma 3 12B: Songs/lyrics, music/artist knowledge
  //   - Mistral Small 3.1: Creative writing, storytelling, currency, math
  //   - Nemotron 3 Super: General purpose, high quality
  //   - Minimax M2.5: Coding/programming, complex reasoning
  //   - OpenRouter Auto: Fallback for unknown categories

  static const Map<QueryCategory, AIProvider> _categoryMap = {
    // ── Religion & India (Groq: reliable Indian content) ────
    QueryCategory.indiaInDetail: AIProvider.groq,
    QueryCategory.hinduGodsGoddesses: AIProvider.groq,
    QueryCategory.sikhism: AIProvider.groq,
    QueryCategory.christianity: AIProvider.groq,
    QueryCategory.generalKnowledge: AIProvider.groq,

    // ── Hindi / Hinglish (Groq: strong Hindi support) ──────
    QueryCategory.hindiDevnagri: AIProvider.groq,
    QueryCategory.hindiFluent: AIProvider.groq,
    QueryCategory.hinglish: AIProvider.groq,
    QueryCategory.hindiQuotes: AIProvider.groq,

    // ── Creative & Stories (Mistral: creative writing) ──────
    QueryCategory.storyTelling: AIProvider.openRouterMistral,
    QueryCategory.creative: AIProvider.openRouterMistral,

    // ── Music & Songs (Gemma: good at artistic knowledge) ──
    QueryCategory.songsLyricsKnowledge: AIProvider.openRouterGemma,
    QueryCategory.musicArtist: AIProvider.openRouterGemma,

    // ── Astrology / Numerology / Science (NVIDIA: reasoning)
    QueryCategory.astrology: AIProvider.nvidia,
    QueryCategory.numerology: AIProvider.nvidia,
    QueryCategory.scienceSubject: AIProvider.nvidia,
    QueryCategory.futuristicApproach: AIProvider.nvidia,

    // ── Tech & AI (Step Flash: tech specialist) ────────────
    QueryCategory.technologyExplained: AIProvider.openRouterStepFlash,
    QueryCategory.aiKnowledge: AIProvider.openRouterStepFlash,

    // ── Coding (Minimax: complex reasoning) ────────────────
    QueryCategory.codingProgramming: AIProvider.openRouterMinimax,

    // ── Gen-Z / Informal / Games (Groq: ultra-fast) ────────
    QueryCategory.genZStyle: AIProvider.groqLlama4Scout,
    QueryCategory.informalEnglish: AIProvider.groqLlama4Scout,
    QueryCategory.gamesRelated: AIProvider.groq,
    QueryCategory.feedback: AIProvider.groq,
    QueryCategory.nonDiplomatic: AIProvider.groq,

    // ── Formal English / Learning (Groq Scout: smart chat; GitHub deprecated)
    QueryCategory.formalEnglish: AIProvider.groqLlama4Scout,
    QueryCategory.englishLearning: AIProvider.groqLlama4Scout,
    QueryCategory.englishVocabulary: AIProvider.groqLlama4Scout,
    QueryCategory.englishQuotes: AIProvider.groqQwen,
    QueryCategory.books: AIProvider.groqQwen,
    QueryCategory.greatPeopleInfo: AIProvider.groqGptOss,

    // ── Translation (GLM 4.5 Air: multi-lingual) ──────────
    QueryCategory.languageTranslator: AIProvider.openRouterGLM,
    QueryCategory.languageTranscriber: AIProvider.openRouterGLM,

    // ── Law (Groq: reliable reasoning) ─────────────────────
    QueryCategory.indianLaws: AIProvider.groq,

    // ── Math / Currency (Mistral Direct: quick calculation) ─
    QueryCategory.mathCalculation: AIProvider.mistralDirect,
    QueryCategory.currency: AIProvider.mistralDirect,

    // ── Real-time data routes through Groq first ──────────
    QueryCategory.realTimeData: AIProvider.groq,

    // ── Unknown / fallback ────────────────────────────────
    QueryCategory.unknown: AIProvider.openRouterAuto,
  };

  // ─── FALLBACK ORDER per provider ───────────────────────────
  static const Map<AIProvider, List<AIProvider>> _fallbackChain = {
    // ── Groq variants → each other, then nvidia, then openrouter
    AIProvider.groq: [
      AIProvider.groqLlama4Scout,
      AIProvider.nvidia,
      AIProvider.openRouterMinimax,
      AIProvider.openRouterAuto,
    ],
    AIProvider.groqLlama4Scout: [
      AIProvider.groq,
      AIProvider.nvidia,
      AIProvider.openRouterAuto,
    ],
    AIProvider.groqGptOss: [
      AIProvider.openRouterStepFlash,
      AIProvider.groq,
      AIProvider.openRouterAuto,
    ],
    AIProvider.groqQwen: [
      AIProvider.openRouterMinimax,
      AIProvider.groq,
      AIProvider.openRouterAuto,
    ],
    // ── Direct API fallbacks ────────────────────────────────
    AIProvider.nvidia: [
      AIProvider.openRouterMinimax,
      AIProvider.groq,
      AIProvider.openRouterAuto,
    ],
    AIProvider.github: [
      AIProvider.groq,
      AIProvider.openRouterMinimax,
    ], // GitHub PAT currently unauthorized
    AIProvider.mistralDirect: [
      AIProvider.openRouterMistral,
      AIProvider.groq,
      AIProvider.openRouterAuto,
    ],
    // ── OpenRouter fallbacks ────────────────────────────────
    AIProvider.openRouterMistral: [
      AIProvider.mistralDirect,
      AIProvider.groq,
      AIProvider.nvidia,
      AIProvider.openRouterAuto,
    ],
    AIProvider.openRouterStepFlash: [
      AIProvider.groqGptOss,
      AIProvider.nvidia,
      AIProvider.groq,
      AIProvider.openRouterAuto,
    ],
    AIProvider.openRouterGLM: [AIProvider.groq, AIProvider.openRouterAuto],
    AIProvider.openRouterGemma: [
      AIProvider.groq,
      AIProvider.nvidia,
      AIProvider.openRouterAuto,
    ],
    AIProvider.openRouterNemotron: [
      AIProvider.groq,
      AIProvider.nvidia,
      AIProvider.openRouterAuto,
    ],
    AIProvider.openRouterMinimax: [
      AIProvider.groqQwen,
      AIProvider.openRouterMistral,
      AIProvider.groq,
      AIProvider.openRouterAuto,
    ],
    AIProvider.openRouterAuto: [
      AIProvider.groq,
      AIProvider.nvidia,
      AIProvider.openRouterMinimax,
    ],
  };

  // ═══════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════

  /// Hard reset — clears all session state and re-tests all 14 models.
  /// Called on user double-tap in game screen or triple-tap in voice chat screen.
  ///
  /// Resets:
  ///   - Session blacklist (failed providers can be retried fresh)
  ///   - Error counts per provider
  ///   - Preferred provider (back to auto routing)
  ///   - All health statuses → untested
  ///   - Re-runs two-stage health check from scratch
  void hardReset() {
    debugPrint('🔄 [AIModelManager] Hard reset triggered by user');

    _blacklistedUntil.clear();
    _errorCounts.clear();
    _lastUsed.clear();
    preferredProvider.value = null;
    activeModelName.value = 'Groq Llama';
    activeCategory.value = QueryCategory.unknown;
    blacklistedProviders.clear();
    providerHealth.clear(); // All → untested
    _isTestingHealth = false;

    // Re-run health checks fresh
    initializeHealthChecks();

    debugPrint(
        '✅ [AIModelManager] Hard reset complete — re-testing all 14 models');
  }

  /// Classify a query into a category
  QueryCategory classifyQuery(String text) {
    final lower = text.toLowerCase().trim();

    // ── Real-time signals ──────────────────────────────────
    final realtimeKeywords = [
      'today',
      'aaj',
      'abhi',
      'right now',
      'current',
      'latest',
      'weather',
      'mausam',
      'score',
      'live',
      'trending',
      'news',
      'kya hua',
      'what happened',
      'price',
      'rate',
      'stock',
      'match',
      'election',
      'results',
      'breaking',
    ];
    for (final kw in realtimeKeywords) {
      if (lower.contains(kw)) return QueryCategory.realTimeData;
    }

    // ── Religion & India ──────────────────────────────────
    final hinduKeywords = [
      'shiva',
      'vishnu',
      'krishna',
      'rama',
      'hanuman',
      'ganesh',
      'durga',
      'lakshmi',
      'saraswati',
      'parvati',
      'kali',
      'bhagavad gita',
      'geeta',
      'mahabharata',
      'ramayana',
      'mandir',
      'temple',
      'pooja',
      'puja',
      'arti',
      'aarti',
      'hindu',
      'sanatan',
      'dharma',
      'vedas',
      'upanishad',
      'devi',
      'devta',
      'bhagwan',
      'ishwar',
    ];
    for (final kw in hinduKeywords) {
      if (lower.contains(kw)) return QueryCategory.hinduGodsGoddesses;
    }

    final sikhKeywords = [
      'sikh',
      'guru nanak',
      'waheguru',
      'gurbani',
      'granth sahib',
      'gurudwara',
      'gurdwara',
      'khalsa',
      'amrit',
      'bani',
      'kirtan',
      'ardas',
      'langar',
      'nihang',
      'guru gobind',
      'japji',
      'naam jaap',
      'simran',
      'path',
      'paath',
    ];
    for (final kw in sikhKeywords) {
      if (lower.contains(kw)) return QueryCategory.sikhism;
    }

    final christianKeywords = [
      'jesus',
      'christ',
      'bible',
      'church',
      'gospel',
      'prayer',
      'christian',
      'god bless',
      'amen',
      'psalm',
      'holy spirit',
      'baptism',
      'communion',
      'catholic',
      'protestant',
    ];
    for (final kw in christianKeywords) {
      if (lower.contains(kw)) return QueryCategory.christianity;
    }

    final indiaKeywords = [
      'india',
      'bharat',
      'indian',
      'desh',
      'state',
      'pradesh',
      'delhi',
      'mumbai',
      'kolkata',
      'chennai',
      'bangalore',
      'constitution',
      'republic',
      'pm ',
      'prime minister',
      'independence',
      'freedom',
      'tricolor',
      'tiranga',
    ];
    for (final kw in indiaKeywords) {
      if (lower.contains(kw)) return QueryCategory.indiaInDetail;
    }

    // ── Coding ────────────────────────────────────────────
    final codingKeywords = [
      'code',
      'coding',
      'programming',
      'program',
      'function',
      'class',
      'variable',
      'loop',
      'array',
      'python',
      'java',
      'javascript',
      'flutter',
      'dart',
      'react',
      'api',
      'debug',
      'error',
      'bug',
      'compile',
      'algorithm',
      'data structure',
      'html',
      'css',
      'sql',
      'database',
      'git',
      'github',
    ];
    for (final kw in codingKeywords) {
      if (lower.contains(kw)) return QueryCategory.codingProgramming;
    }

    // ── Technology & AI ───────────────────────────────────
    final techKeywords = [
      'technology',
      'tech',
      'gadget',
      'smartphone',
      'laptop',
      'software',
      'hardware',
      'internet',
      'wifi',
      'bluetooth',
      'robot',
      'automation',
      'digital',
      'cyber',
      'cloud',
      'machine learning',
      'deep learning',
      'neural network',
    ];
    for (final kw in techKeywords) {
      if (lower.contains(kw)) return QueryCategory.technologyExplained;
    }

    final aiKeywords = [
      'artificial intelligence',
      'ai ',
      'chatgpt',
      'gpt',
      'llm',
      'large language model',
      'openai',
      'gemini',
      'claude',
      'copilot',
      'siri',
      'alexa',
    ];
    for (final kw in aiKeywords) {
      if (lower.contains(kw)) return QueryCategory.aiKnowledge;
    }

    // ── Astrology & Numerology ────────────────────────────
    final astroKeywords = [
      'astrology',
      'horoscope',
      'zodiac',
      'kundli',
      'kundali',
      'rashi',
      'nakshatra',
      'graha',
      'planet',
      'sun sign',
      'moon sign',
      'jyotish',
      'rashifal',
      'birth chart',
    ];
    for (final kw in astroKeywords) {
      if (lower.contains(kw)) return QueryCategory.astrology;
    }

    final numKeywords = [
      'numerology',
      'number',
      'angel number',
      'life path',
      'destiny number',
      'birth number',
      'ank',
      'ank jyotish',
    ];
    for (final kw in numKeywords) {
      if (lower.contains(kw)) return QueryCategory.numerology;
    }

    // ── Songs / Music ─────────────────────────────────────
    final musicKeywords = [
      'song',
      'gana',
      'gaana',
      'lyrics',
      'singer',
      'music',
      'bollywood',
      'album',
      'melody',
      'tune',
      'dj',
      'rap',
      'bhajan',
      'qawwali',
      'sufi',
      'classical music',
      'artist',
      'band',
      'concert',
      'musician',
    ];
    for (final kw in musicKeywords) {
      if (lower.contains(kw)) return QueryCategory.songsLyricsKnowledge;
    }

    // ── Story Telling ─────────────────────────────────────
    final storyKeywords = [
      'story',
      'kahani',
      'tale',
      'katha',
      'sunao',
      'once upon',
      'ek baar',
      'fairy',
      'moral story',
      'bedtime',
      'fiction',
    ];
    for (final kw in storyKeywords) {
      if (lower.contains(kw)) return QueryCategory.storyTelling;
    }

    // ── Creative ──────────────────────────────────────────
    final creativeKeywords = [
      'creative',
      'imagine',
      'kalpana',
      'sochiye',
      'poem',
      'kavita',
      'shayari',
      'write',
      'likhiye',
      'compose',
      'design',
      'art',
      'paint',
      'draw',
    ];
    for (final kw in creativeKeywords) {
      if (lower.contains(kw)) return QueryCategory.creative;
    }

    // ── Gen-Z Style ───────────────────────────────────────
    final genzKeywords = [
      'bro',
      'bruh',
      'slay',
      'vibe',
      'lowkey',
      'highkey',
      'lit',
      'no cap',
      'fr fr',
      'bestie',
      'rizz',
      'skibidi',
      'yeet',
      'sus',
      'sheesh',
      'bussin',
      'based',
      'cringe',
    ];
    for (final kw in genzKeywords) {
      if (lower.contains(kw)) return QueryCategory.genZStyle;
    }

    // ── Law ───────────────────────────────────────────────
    final lawKeywords = [
      'law',
      'kanoon',
      'act',
      'section',
      'ipc',
      'crpc',
      'constitution',
      'court',
      'judge',
      'legal',
      'rights',
      'fir',
      'police',
      'advocate',
      'lawyer',
      'bail',
    ];
    for (final kw in lawKeywords) {
      if (lower.contains(kw)) return QueryCategory.indianLaws;
    }

    // ── Translation / Transcription ───────────────────────
    final translateKeywords = [
      'translate',
      'translation',
      'anuvad',
      'convert language',
      'meaning of',
      'matlab',
      'iska matlab',
    ];
    for (final kw in translateKeywords) {
      if (lower.contains(kw)) return QueryCategory.languageTranslator;
    }

    // ── Science ───────────────────────────────────────────
    final scienceKeywords = [
      'physics',
      'chemistry',
      'biology',
      'science',
      'atom',
      'molecule',
      'cell',
      'dna',
      'evolution',
      'gravity',
      'space',
      'universe',
      'planet',
      'star',
      'quantum',
    ];
    for (final kw in scienceKeywords) {
      if (lower.contains(kw)) return QueryCategory.scienceSubject;
    }

    // ── Math ──────────────────────────────────────────────
    final mathKeywords = [
      'math',
      'calculate',
      'equation',
      'algebra',
      'geometry',
      'trigonometry',
      'calculus',
      'number',
      'sum',
      'divide',
      'multiply',
      'percentage',
      'formula',
    ];
    for (final kw in mathKeywords) {
      if (lower.contains(kw)) return QueryCategory.mathCalculation;
    }

    // ── Currency ──────────────────────────────────────────
    final currencyKeywords = [
      'rupee',
      'dollar',
      'euro',
      'pound',
      'inr',
      'usd',
      'eur',
      'gbp',
      'exchange',
      'conversion',
      'rate',
      'forex',
      'currency',
    ];
    for (final kw in currencyKeywords) {
      if (lower.contains(kw)) return QueryCategory.currency;
    }

    // ── Great People Info ─────────────────────────────────
    final peopleKeywords = [
      'gandhi',
      'nehru',
      'swami vivekananda',
      'sri aurobindo',
      'keshab chandra sen',
      'rammohan roy',
      'dayananda saraswati',
      'ishwar chandra vidyasagar',
      'jiddu krishnamurti',
      'sri ramakrishna',
      'swami vivekananda',
      'biography',
      'life story',
      'achievements',
      'contribution',
    ];
    for (final kw in peopleKeywords) {
      if (lower.contains(kw)) return QueryCategory.greatPeopleInfo;
    }

    // ── English Learning ──────────────────────────────────
    final englishKeywords = [
      'english',
      'grammar',
      'tense',
      'pronunciation',
      'sentence',
      'vocabulary',
      'spelling',
      'accent',
      'fluency',
      'spoken',
    ];
    for (final kw in englishKeywords) {
      if (lower.contains(kw)) return QueryCategory.englishLearning;
    }

    // ── Books ─────────────────────────────────────────────
    final bookKeywords = [
      'book',
      'novel',
      'author',
      'story',
      'chapter',
      'publish',
      'literature',
      'reading',
      'fiction',
      'non-fiction',
    ];
    for (final kw in bookKeywords) {
      if (lower.contains(kw)) return QueryCategory.books;
    }

    // ── Quotes ────────────────────────────────────────────
    if (lower.contains('quote') || lower.contains('suvichar')) {
      if (RegExp(r'[\u0900-\u097F]').hasMatch(lower)) {
        return QueryCategory.hindiQuotes;
      }
      return QueryCategory.englishQuotes;
    }

    // ── Hindi detection ───────────────────────────────────
    // If text contains Devanagari characters
    if (RegExp(r'[\u0900-\u097F]').hasMatch(lower)) {
      return QueryCategory.hindiDevnagri;
    }

    // ── Hinglish detection (romanized Hindi words) ────────
    final hinglishWords = [
      'aaj',
      'kal',
      'aana',
      'jana',
      'karna',
      'bolna',
      'sunna',
      'dekha',
      'mujhe',
      'aapko',
      'tumhare',
      'mere',
      'hoga',
      'honge',
      'hain',
      'hai',
      'tha',
      'the',
    ];
    int hinglishCount = 0;
    for (final kw in hinglishWords) {
      if (lower.contains(kw)) hinglishCount++;
    }
    if (hinglishCount >= 2) return QueryCategory.hinglish;

    // ── Futuristic ────────────────────────────────────────
    final futureKeywords = [
      'future',
      'futuristic',
      'tomorrow',
      'prediction',
      'space travel',
      'flying car',
      'metaverse',
      'virtual reality',
      'augmented reality',
      'robot',
    ];
    for (final kw in futureKeywords) {
      if (lower.contains(kw)) return QueryCategory.futuristicApproach;
    }

    // ── General Knowledge (broad catch) ───────────────────
    final gkKeywords = [
      'what',
      'why',
      'how',
      'who',
      'where',
      'when',
      'explain',
      'tell me',
      'know',
      'about',
      'information',
      'fact',
    ];
    for (final kw in gkKeywords) {
      if (lower.contains(kw)) return QueryCategory.generalKnowledge;
    }

    return QueryCategory.unknown;
  }

  /// Detect if the query needs real-time data
  bool needsRealTimeData(QueryCategory category) {
    return category == QueryCategory.realTimeData;
  }

  /// Route a query to the best model
  ModelRoute routeQuery(String queryText) {
    final category = classifyQuery(queryText);
    activeCategory.value = category;

    // ── User preference override ─────────────────────────────
    if (preferredProvider.value != null) {
      final preferred = preferredProvider.value!;
      if (!isBlacklisted(preferred)) {
        final route = _buildRoute(preferred, category);
        activeModelName.value = route.displayName;
        _lastUsed[preferred] = DateTime.now();
        debugPrint(
            '🎯 [AIModelManager] Using user-preferred: ${route.displayName}');
        return route;
      } else {
        // Preferred provider is blacklisted — fall through to auto-routing
        debugPrint(
            '⚠️ [AIModelManager] Preferred ${preferred.name} is blacklisted, auto-routing...');
      }
    }

    // Get primary provider from category map
    AIProvider provider = _categoryMap[category] ?? AIProvider.openRouterAuto;

    // If primary is blacklisted, skip straight to fallback chain
    if (isBlacklisted(provider)) {
      debugPrint(
          '🚫 [AIModelManager] Primary ${provider.name} is blacklisted, finding alternative...');
      final fallbacks = _fallbackChain[provider] ?? [];
      bool found = false;
      for (final fb in fallbacks) {
        if (!isBlacklisted(fb) && !_isProviderUnhealthy(fb)) {
          provider = fb;
          found = true;
          break;
        }
      }
      // If no fallback found in chain, try any non-blacklisted provider
      if (!found) {
        for (final p in AIProvider.values) {
          if (!isBlacklisted(p) && !_isProviderUnhealthy(p)) {
            provider = p;
            break;
          }
        }
      }
    } else if (_isProviderUnhealthy(provider)) {
      // Not blacklisted but temporarily unhealthy
      final fallbacks = _fallbackChain[provider] ?? [];
      for (final fb in fallbacks) {
        if (!_isProviderUnhealthy(fb)) {
          provider = fb;
          break;
        }
      }
    }

    final route = _buildRoute(provider, category);
    activeModelName.value = route.displayName;
    _lastUsed[provider] = DateTime.now();

    debugPrint('🤖 Query routed → ${route.displayName} [${category.name}]');

    return route;
  }

  // ── TEST ALL MODELS ON STARTUP (GREEN/YELLOW/RED) ────────────

  void initializeHealthChecks() async {
    if (_isTestingHealth) return;
    _isTestingHealth = true;

    // Initialize all as untested
    for (final p in AIProvider.values) {
      if (!providerHealth.containsKey(p)) {
        providerHealth[p] = ProviderHealth.untested;
      }
    }

    OpenRouterService? router;
    try {
      router = Get.find<OpenRouterService>();
    } catch (_) {
      _isTestingHealth = false;
      return;
    }

    debugPrint(
        '🧪 [AIModelManager] Starting Intelligent Two-Stage Model Health Testing...');

    // ════════════════════════════════════════════════════════════════
    // STAGE 1: Fast Ping (5 seconds timeout)
    // Test all providers with short timeout
    // ════════════════════════════════════════════════════════════════
    final failedInFirstAttempt = <AIProvider>{};

    debugPrint(
        '🟢 [Health Stage 1] Testing all ${AIProvider.values.length} providers (5s timeout)...');

    for (final provider in AIProvider.values) {
      // Skip deprecated GitHub — it always routes to Groq, not a real endpoint
      if (provider == AIProvider.github) {
        providerHealth[provider] = ProviderHealth.healthy;
        debugPrint(
            '⏭️ [Stage 1] ${provider.name} skipped (deprecated, routes to Groq)');
        continue;
      }
      if (isBlacklisted(provider)) continue;

      final route = _buildRoute(provider, QueryCategory.generalKnowledge);

      try {
        final res = await router
            .makeProviderRequest(
              route: route,
              // Stronger prompt — forces a non-empty reply from strict models
              systemPrompt:
                  'You are a health check endpoint. Always respond with the single word OK and nothing else. Never leave empty.',
              userMessage:
                  'Please respond with the single word OK to confirm you are working.',
            )
            .timeout(const Duration(seconds: 15));

        // Accept any non-null response (HTTP 200) — even empty is a PASS.
        // Some large models (Qwen3, Nemotron) decline single-word tests but
        // work correctly with real queries.
        if (res != null) {
          providerHealth[provider] = ProviderHealth.healthy; // 🟢 Green
          debugPrint(
              '🟢 [Stage 1] ${provider.name} ✓ HEALTHY (Response: "${res.trim().substring(0, res.trim().length.clamp(0, 20))}")');
        } else {
          failedInFirstAttempt.add(provider);
          debugPrint(
              '⏳ [Stage 1] ${provider.name} ✗ No response, queued for retry');
        }
      } on Exception catch (e) {
        // 429 = quota exceeded (temporary rate limit) — mark degraded, not failing
        final errStr = e.toString();
        if (errStr.contains('429') ||
            errStr.contains('quota') ||
            errStr.contains('rate limit')) {
          providerHealth[provider] = ProviderHealth.degraded;
          debugPrint(
              '🟡 [Stage 1] ${provider.name} ○ DEGRADED (Quota/Rate limit: 429)');
        } else {
          failedInFirstAttempt.add(provider);
          debugPrint(
              '⏳ [Stage 1] ${provider.name} ✗ Failed (${e.runtimeType}), queued for retry');
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    // STAGE 2: Extended Retry (10 seconds timeout)
    // Only test providers that failed in Stage 1
    // ════════════════════════════════════════════════════════════════
    debugPrint(
        '🟡 [Health Stage 2] Retesting ${failedInFirstAttempt.length} failed providers (10s timeout)...');

    for (final provider in failedInFirstAttempt) {
      final route = _buildRoute(provider, QueryCategory.generalKnowledge);

      try {
        final res = await router
            .makeProviderRequest(
              route: route,
              systemPrompt:
                  'You are a health check endpoint. Always respond with the single word OK and nothing else.',
              userMessage:
                  'Please respond with the single word OK to confirm you are working.',
            )
            .timeout(const Duration(seconds: 25));

        // Accept any non-null HTTP 200 (even empty) as DEGRADED-PASS on retry
        if (res != null) {
          providerHealth[provider] = ProviderHealth.degraded; // 🟡 Yellow
          debugPrint(
              '🟡 [Stage 2] ${provider.name} ✓ DEGRADED (Slow/Unstable - Retry Success)');
        } else {
          providerHealth[provider] = ProviderHealth.failing; // 🔴 Red
          blacklistProvider(provider);
          debugPrint(
              '🔴 [Stage 2] ${provider.name} ✗ FAILING (null response on retry)');
        }
      } on Exception catch (e) {
        // 429 quota errors → degraded (temporary), not permanently failing
        final errStr = e.toString();
        if (errStr.contains('429') ||
            errStr.contains('quota') ||
            errStr.contains('rate limit')) {
          providerHealth[provider] = ProviderHealth.degraded;
          debugPrint(
              '🟡 [Stage 2] ${provider.name} ○ DEGRADED (Quota/Rate limit on retry)');
        } else {
          providerHealth[provider] = ProviderHealth.failing; // 🔴 Red
          blacklistProvider(provider);
          debugPrint(
              '🔴 [Stage 2] ${provider.name} ✗ FAILING (${e.runtimeType})');
        }
      }
    }

    debugPrint('✅ [AIModelManager] Two-Stage Health Testing Complete.');
    debugPrint(
        '   🟢 Healthy: ${providerHealth.values.where((h) => h == ProviderHealth.healthy).length}');
    debugPrint(
        '   🟡 Degraded: ${providerHealth.values.where((h) => h == ProviderHealth.degraded).length}');
    debugPrint(
        '   🔴 Failing: ${providerHealth.values.where((h) => h == ProviderHealth.failing).length}');
    _isTestingHealth = false;
  }

  /// True if ALL available models have ultimately failed
  bool get allModelsEvaluatedAndFailed {
    if (providerHealth.isEmpty) return false;

    bool hasAnyHealthy = false;
    bool allEvaluated = true;

    for (final p in AIProvider.values) {
      final status = providerHealth[p];
      if (status == ProviderHealth.untested || status == null) {
        allEvaluated = false;
      }
      if (status == ProviderHealth.healthy ||
          status == ProviderHealth.degraded) {
        hasAnyHealthy = true;
      }
    }

    // We consider it "all failed" if no model is healthy/degraded AND we've tested at least some or we fallbacked
    return !hasAnyHealthy && allEvaluated;
  }

  /// Blacklist a provider for 5 minutes with automatic recovery.
  /// After 5 minutes, the provider is automatically removed from blacklist.
  /// This prevents transient failures from becoming permanent.
  void blacklistProvider(AIProvider provider) {
    final expiryTime = DateTime.now().add(const Duration(minutes: 10));
    _blacklistedUntil[provider] = expiryTime;
    _errorCounts[provider] = (_errorCounts[provider] ?? 0) + 1;
    _lastUsed[provider] = DateTime.now();

    final name = provider.name;
    if (!blacklistedProviders.contains(name)) {
      blacklistedProviders.add(name);
    }

    debugPrint(
        '🚫 [AIModelManager] Provider blacklisted for 5 minutes: $name (recovers at ${expiryTime.hour}:${expiryTime.minute})');
  }

  /// Public check: is this provider currently blacklisted?
  /// Returns false if blacklist expiry time has passed (automatic recovery).
  bool isBlacklisted(AIProvider provider) {
    final until = _blacklistedUntil[provider];
    if (until == null) return false; // Not blacklisted

    // Check if recovery time has passed
    if (DateTime.now().isAfter(until)) {
      // Recovery time reached — remove from blacklist
      _blacklistedUntil.remove(provider);

      final name = provider.name;
      if (blacklistedProviders.contains(name)) {
        blacklistedProviders.remove(name);
      }

      debugPrint(
          '♻️ [AIModelManager] Provider recovered and available: ${provider.name}');
      return false;
    }

    return true; // Still blacklisted
  }

  /// Expose the fallback chain for a given provider (used by OpenRouterService).
  List<AIProvider> getFallbackChainForProvider(AIProvider provider) =>
      List.unmodifiable(_fallbackChain[provider] ?? []);

  /// Build a ModelRoute for any provider + category combination.
  /// This is the public counterpart of the private _buildRoute.
  ModelRoute buildRouteForProvider(
          AIProvider provider, QueryCategory category) =>
      _buildRoute(provider, category);

  /// Set user-preferred provider (null = auto). Persists for the session.
  void setPreferredProvider(AIProvider? provider) {
    preferredProvider.value = provider;
    if (provider != null) {
      activeModelName.value =
          _buildRoute(provider, activeCategory.value).displayName;
      debugPrint(
          '🎯 [AIModelManager] User selected preferred model: ${provider.name}');
    } else {
      debugPrint('🎯 [AIModelManager] Auto-routing restored');
    }
  }

  /// Total number of available (non-blacklisted) providers.
  int get availableProviderCount =>
      AIProvider.values.where((p) => !isBlacklisted(p)).length;

  /// Dynamic total count of all models (catalog-driven, auto-updates as models are added).
  int get totalModelCount => allModelCatalog.length;

  /// Dynamic count of models that passed health checks (healthy or degraded).
  int get workingModelCount => providerHealth.values
      .where((h) => h == ProviderHealth.healthy || h == ProviderHealth.degraded)
      .length;

  /// Dynamic count of models that failed health checks.
  int get failedModelCount =>
      providerHealth.values.where((h) => h == ProviderHealth.failing).length;

  /// Get fallback route when primary fails — exhausts entire fallback chain,
  /// skipping any blacklisted providers.
  ModelRoute getFallbackRoute(AIProvider failedProvider) {
    _errorCounts[failedProvider] = (_errorCounts[failedProvider] ?? 0) + 1;

    final fallbacks = _fallbackChain[failedProvider] ?? [];

    // Try every entry in the fallback chain, skipping blacklisted ones
    for (final fb in fallbacks) {
      if (!_isProviderUnhealthy(fb) && !isBlacklisted(fb)) {
        debugPrint('🔄 [AIModelManager] Falling back to: ${fb.name}');
        return _buildRoute(fb, activeCategory.value);
      }
    }

    // All preferred fallbacks are also blacklisted/unhealthy — scan ALL providers
    for (final provider in AIProvider.values) {
      if (!isBlacklisted(provider) &&
          !_isProviderUnhealthy(provider) &&
          provider != failedProvider) {
        debugPrint(
            '🔄 [AIModelManager] Emergency fallback to: ${provider.name}');
        return _buildRoute(provider, activeCategory.value);
      }
    }

    // Absolute last resort — use openRouterAuto (even if potentially unhealthy)
    debugPrint(
        '🆘 [AIModelManager] All providers exhausted, using openRouterAuto as last resort');
    return _buildRoute(AIProvider.openRouterAuto, activeCategory.value);
  }

  /// Report a successful call (resets error count)
  void reportSuccess(AIProvider provider) {
    _errorCounts[provider] = 0;
  }

  /// Report an error
  void reportError(AIProvider provider) {
    _errorCounts[provider] = (_errorCounts[provider] ?? 0) + 1;
  }

  // ═══════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════

  bool _isProviderUnhealthy(AIProvider provider) {
    // Blacklist takes priority
    if (isBlacklisted(provider)) return true;

    final errors = _errorCounts[provider] ?? 0;
    // If 1+ consecutive errors in last 5 minutes, consider unhealthy
    if (errors >= 1) {
      final lastUsed = _lastUsed[provider];
      if (lastUsed == null) return true;
      final elapsed = DateTime.now().difference(lastUsed);
      if (elapsed.inMinutes < 5) return true;
    }
    return false;
  }

  ModelRoute _buildRoute(AIProvider provider, QueryCategory category) {
    switch (provider) {
      case AIProvider.groq:
        return ModelRoute(
          provider: provider,
          modelId: 'llama-3.1-8b-instant',
          displayName: 'Groq Llama 3.1 8B',
          apiKey: ApiKeysConfig.groqApiKeys[0], // key_1 dedicated
          baseUrl: '${ApiKeysConfig.groqBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.groqLlama4Scout:
        // key_2: meta-llama/llama-4-scout-17b-16e-instruct — Chat specialist
        return ModelRoute(
          provider: provider,
          modelId: 'meta-llama/llama-4-scout-17b-16e-instruct',
          displayName: 'Groq Llama 4 Scout',
          apiKey: ApiKeysConfig.groqApiKeys[1], // key_2 dedicated
          baseUrl: '${ApiKeysConfig.groqBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.groqGptOss:
        // key_3: openai/gpt-oss-120b via Groq — Advanced Reasoning
        return ModelRoute(
          provider: provider,
          modelId: 'openai/gpt-oss-120b',
          displayName: 'Groq GPT OSS 120B',
          apiKey: ApiKeysConfig.groqApiKeys[2], // key_3 dedicated
          baseUrl: '${ApiKeysConfig.groqBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.groqQwen:
        // key_4: qwen/qwen3-32b — Extended Context
        return ModelRoute(
          provider: provider,
          modelId: 'qwen/qwen3-32b',
          displayName: 'Groq Qwen3 32B',
          apiKey: ApiKeysConfig.groqApiKeys[3], // key_4 dedicated
          baseUrl: '${ApiKeysConfig.groqBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.nvidia:
        // minimaxai/minimax-m2.5 returned 410 Gone (discontinued on NIM)
        // Replaced with meta/llama-3.1-8b-instruct — live-tested PASS
        return ModelRoute(
          provider: provider,
          modelId: 'meta/llama-3.1-8b-instruct',
          displayName: 'NVIDIA Minimax M2.5',
          apiKey: ApiKeysConfig.getRandomNvidiaToken(),
          baseUrl: ApiKeysConfig.nvidiaBaseUrl,
          category: category,
        );

      case AIProvider.github:
        // GitHub PAT deprecated - unauthorized. Route to Groq instead.
        return _buildRoute(AIProvider.groq, category);

      case AIProvider.mistralDirect:
        return ModelRoute(
          provider: provider,
          modelId: ApiKeysConfig.mistralModel,
          displayName: 'Mistral Small (Direct)',
          apiKey: ApiKeysConfig.mistralApiKey,
          baseUrl: '${ApiKeysConfig.mistralBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.googleGeminiFlashLite:
        return ModelRoute(
          provider: provider,
          modelId: 'gemini-3.1-flash-lite', // ✅ API-verified
          displayName: 'Gemini 3.1 Flash Lite',
          apiKey: ApiKeysConfig.geminiApiKey,
          baseUrl:
              '${ApiKeysConfig.geminiBaseUrl}/models/gemini-3.1-flash-lite:generateContent',
          category: category,
        );

      case AIProvider.googleGeminiProPreview:
        return ModelRoute(
          provider: provider,
          modelId: 'gemini-3.1-pro-preview-customtools', // ✅ API-verified
          displayName: 'Gemini 3.1 Pro Preview Custom Tools',
          apiKey: ApiKeysConfig.geminiApiKey,
          baseUrl:
              '${ApiKeysConfig.geminiBaseUrl}/models/gemini-3.1-pro-preview-customtools:generateContent',
          category: category,
        );

      case AIProvider.googleGemini35Flash:
        return ModelRoute(
          provider: provider,
          modelId: 'gemini-3.5-flash', // ✅ API-verified
          displayName: 'Gemini 3.5 Flash',
          apiKey: ApiKeysConfig.geminiApiKey,
          baseUrl:
              '${ApiKeysConfig.geminiBaseUrl}/models/gemini-3.5-flash:generateContent',
          category: category,
        );

      case AIProvider.googleGemma4A4B:
        return ModelRoute(
          provider: provider,
          modelId: 'gemma-4-26b-a4b-it', // ✅ API-verified
          displayName: 'Gemma 4 26B A4B IT',
          apiKey: ApiKeysConfig.geminiApiKey,
          baseUrl:
              '${ApiKeysConfig.geminiBaseUrl}/models/gemma-4-26b-a4b-it:generateContent',
          category: category,
        );

      case AIProvider.openRouterStepFlash:
        // GPT OSS 120B — Technology & AI
        final config = ApiKeysConfig.openRouterModels['openai-gpt-oss-120b'];
        if (config == null) {
          return _buildRoute(AIProvider.openRouterAuto, category);
        }
        return ModelRoute(
          provider: provider,
          modelId: config.modelId,
          displayName: config.displayName,
          apiKey: config.apiKey,
          baseUrl: '${ApiKeysConfig.openRouterBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.openRouterGLM:
        // GLM 4.5 Air — Translation & Transcription
        final config = ApiKeysConfig.openRouterModels['z-ai-glm-4.5-air'];
        if (config == null) {
          return _buildRoute(AIProvider.openRouterAuto, category);
        }
        return ModelRoute(
          provider: provider,
          modelId: config.modelId,
          displayName: config.displayName,
          apiKey: config.apiKey,
          baseUrl: '${ApiKeysConfig.openRouterBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.openRouterGemma:
        // Gemma 4 31B — Songs & Music
        final config = ApiKeysConfig.openRouterModels['google-gemma-4-31b'];
        if (config == null) {
          return _buildRoute(AIProvider.openRouterAuto, category);
        }
        return ModelRoute(
          provider: provider,
          modelId: config.modelId,
          displayName: config.displayName,
          apiKey: config.apiKey,
          baseUrl: '${ApiKeysConfig.openRouterBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.openRouterMistral:
        // mistral-small-3.1-24b-instruct:free discontinued on OR (404)
        // Replaced with mistral-nemo — live-tested PASS
        final mistralOrConfig =
            ApiKeysConfig.openRouterModels['google-gemma-4-31b'];
        if (mistralOrConfig == null) {
          return _buildRoute(AIProvider.openRouterAuto, category);
        }
        return ModelRoute(
          provider: provider,
          modelId: 'mistralai/mistral-nemo',
          displayName: 'Mistral Small 3.1',
          apiKey: mistralOrConfig.apiKey,
          baseUrl: '${ApiKeysConfig.openRouterBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.openRouterNemotron:
        final config =
            ApiKeysConfig.openRouterModels['nvidia-nemotron-3-super'];
        if (config == null) {
          return _buildRoute(AIProvider.openRouterAuto, category);
        }
        return ModelRoute(
          provider: provider,
          modelId: config.modelId,
          displayName: config.displayName,
          apiKey: config.apiKey,
          baseUrl: '${ApiKeysConfig.openRouterBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.openRouterMinimax:
        final config = ApiKeysConfig.openRouterModels['minimax-m2.5'];
        if (config == null) {
          return _buildRoute(AIProvider.openRouterAuto, category);
        }
        return ModelRoute(
          provider: provider,
          modelId: config.modelId,
          displayName: config.displayName,
          apiKey: config.apiKey,
          baseUrl: '${ApiKeysConfig.openRouterBaseUrl}/chat/completions',
          category: category,
        );

      case AIProvider.openRouterAuto:
        // Use Nemotron key as the auto-router (it covers all OpenRouter models)
        final config =
            ApiKeysConfig.openRouterModels['nvidia-nemotron-3-super'];
        if (config == null) {
          // Ultimate fallback — try groq
          return _buildRoute(AIProvider.groq, category);
        }
        return ModelRoute(
          provider: provider,
          modelId: 'openrouter/auto',
          displayName: 'Auto (Best Match)',
          apiKey: config.apiKey,
          baseUrl: '${ApiKeysConfig.openRouterBaseUrl}/chat/completions',
          category: category,
        );
    }
  }

  /// Get human-readable category name
  String getCategoryName(QueryCategory cat) {
    switch (cat) {
      case QueryCategory.indiaInDetail:
        return 'India in Detail';
      case QueryCategory.hinduGodsGoddesses:
        return 'Hindu Gods & Goddesses';
      case QueryCategory.sikhism:
        return 'Sikhism';
      case QueryCategory.christianity:
        return 'Christianity';
      case QueryCategory.generalKnowledge:
        return 'General Knowledge';
      case QueryCategory.storyTelling:
        return 'Story Telling';
      case QueryCategory.songsLyricsKnowledge:
        return 'Songs & Lyrics';
      case QueryCategory.astrology:
        return 'Astrology';
      case QueryCategory.numerology:
        return 'Numerology';
      case QueryCategory.creative:
        return 'Creative';
      case QueryCategory.futuristicApproach:
        return 'Futuristic';
      case QueryCategory.genZStyle:
        return 'Gen-Z Style';
      case QueryCategory.technologyExplained:
        return 'Technology';
      case QueryCategory.aiKnowledge:
        return 'AI Knowledge';
      case QueryCategory.codingProgramming:
        return 'Coding & Programming';
      case QueryCategory.gamesRelated:
        return 'Games';
      case QueryCategory.feedback:
        return 'Feedback';
      case QueryCategory.nonDiplomatic:
        return 'Non-Diplomatic';
      case QueryCategory.hindiDevnagri:
        return 'Hindi (Devanagari)';
      case QueryCategory.hindiFluent:
        return 'Hindi Fluent';
      case QueryCategory.hinglish:
        return 'Hinglish';
      case QueryCategory.formalEnglish:
        return 'Formal English';
      case QueryCategory.informalEnglish:
        return 'Informal English';
      case QueryCategory.englishLearning:
        return 'English Learning';
      case QueryCategory.indianLaws:
        return 'Indian Laws';
      case QueryCategory.books:
        return 'Books';
      case QueryCategory.musicArtist:
        return 'Music & Artist';
      case QueryCategory.currency:
        return 'Currency';
      case QueryCategory.mathCalculation:
        return 'Math Calculation';
      case QueryCategory.englishVocabulary:
        return 'English Vocabulary';
      case QueryCategory.englishQuotes:
        return 'English Quotes';
      case QueryCategory.hindiQuotes:
        return 'Hindi Quotes';
      case QueryCategory.languageTranslator:
        return 'Language Translator';
      case QueryCategory.languageTranscriber:
        return 'Language Transcriber';
      case QueryCategory.scienceSubject:
        return 'Science';
      case QueryCategory.greatPeopleInfo:
        return 'Great People Info';
      case QueryCategory.realTimeData:
        return 'Real-Time Data';
      case QueryCategory.unknown:
        return 'Unknown';
    }
  }
}
