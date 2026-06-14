/// Language group categories
enum LanguageGroup { main, nativeIndian, international }

/// TTS engine options
enum TTSEngine { flutterTts, sherpaOnnxPiper, sherpaOnnxEspeak }

/// Represents a single downloadable voice option
class VoiceOption {
  final String id;
  final String label;
  final String gender; // 'male', 'female', 'neutral'
  final String quality; // 'x_low', 'low', 'medium', 'high'
  final String modelUrl;
  final String configUrl;
  final int sizeMB;
  final bool isSystem; // true = no download needed, uses flutter_tts
  final String? espeakVoiceOverride;

  const VoiceOption({
    required this.id,
    required this.label,
    required this.gender,
    required this.quality,
    this.modelUrl = '',
    this.configUrl = '',
    this.sizeMB = 0,
    this.isSystem = false,
    this.espeakVoiceOverride,
  });
}

/// Trigger word type for voice commands
enum TriggerWordType { endOfThought, exit }

/// Represents a full language with metadata and voice options
class LanguageModel {
  final String code; // BCP-47
  final String name; // English name
  final String nativeName; // In native script
  final String flag; // Emoji
  final LanguageGroup group;
  final TTSEngine ttsEngine;
  final String? piperModelId;
  final String? espeakVoice;
  final String sttLocale; // BCP-47 for STT
  final List<VoiceOption> voices;
  final String endOfThoughtTrigger;
  final List<String> endOfThoughtVariants;
  final String exitTrigger;
  final List<String> exitTriggerVariants;
  final String? translationLLMCode;

  const LanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.group,
    required this.ttsEngine,
    this.piperModelId,
    this.espeakVoice,
    required this.sttLocale,
    required this.voices,
    this.endOfThoughtTrigger = '',
    this.endOfThoughtVariants = const [],
    this.exitTrigger = '',
    this.exitTriggerVariants = const [],
    this.translationLLMCode,
  });
}
