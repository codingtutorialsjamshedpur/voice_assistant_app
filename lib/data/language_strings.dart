/// ════════════════════════════════════════════════════════════════
/// Language Strings — Localized response templates
/// ════════════════════════════════════════════════════════════════
///
/// Provides reusable localized strings for the AI assistant to use
/// when generating responses in Hindi, English, and Hinglish.
///
/// Mapped to task.md Task 4.3: Add Language Support
/// ════════════════════════════════════════════════════════════════
library;

/// Supported languages for the AI assistant
enum AssistantLanguage {
  hindi,
  english,
  hinglish,
}

class LanguageStrings {
  // ── Singleton ────────────────────────────────────────────────
  LanguageStrings._();

  // ═══════════════════════════════════════════════════════════════
  // GREETINGS
  // ═══════════════════════════════════════════════════════════════

  static const Map<AssistantLanguage, String> greeting = {
    AssistantLanguage.hindi: 'नमस्ते! मैं आपकी मदद कैसे कर सकता हूँ?',
    AssistantLanguage.english: 'Hello! How can I help you?',
    AssistantLanguage.hinglish: 'Hello! Main aapki kaise madad kar sakta hoon?',
  };

  static const Map<AssistantLanguage, String> farewell = {
    AssistantLanguage.hindi: 'अलविदा! जल्द मिलते हैं।',
    AssistantLanguage.english: 'Goodbye! See you soon.',
    AssistantLanguage.hinglish: 'Goodbye! Phir milenge.',
  };

  static const Map<AssistantLanguage, String> thankYou = {
    AssistantLanguage.hindi: 'धन्यवाद!',
    AssistantLanguage.english: 'Thank you!',
    AssistantLanguage.hinglish: 'Shukriya!',
  };

  // ═══════════════════════════════════════════════════════════════
  // ERROR RESPONSES
  // ═══════════════════════════════════════════════════════════════

  static const Map<AssistantLanguage, String> didNotUnderstand = {
    AssistantLanguage.hindi:
        'माफ कीजिए, मुझे समझ नहीं आया। क्या आप फिर से कह सकते हैं?',
    AssistantLanguage.english:
        "Sorry, I didn't quite catch that. Could you say that again?",
    AssistantLanguage.hinglish:
        'Sorry, samajh nahi aaya. Kya aap dobara bol sakte hain?',
  };

  static const Map<AssistantLanguage, String> errorOccurred = {
    AssistantLanguage.hindi: 'एक समस्या आई। कृपया फिर से कोशिश करें।',
    AssistantLanguage.english: 'Something went wrong. Please try again.',
    AssistantLanguage.hinglish:
        'Kuch gadbad ho gayi. Please dobara try karein.',
  };

  static const Map<AssistantLanguage, String> noInternet = {
    AssistantLanguage.hindi:
        'इंटरनेट कनेक्शन नहीं है। कृपया अपना नेटवर्क जांचें।',
    AssistantLanguage.english:
        'No internet connection. Please check your network.',
    AssistantLanguage.hinglish: 'Internet nahi hai. Apna network check karein.',
  };

  // ═══════════════════════════════════════════════════════════════
  // VOICE ASSISTANT STATES
  // ═══════════════════════════════════════════════════════════════

  static const Map<AssistantLanguage, String> listeningStarted = {
    AssistantLanguage.hindi: 'सुन रहा हूँ…',
    AssistantLanguage.english: 'Listening…',
    AssistantLanguage.hinglish: 'Sun raha hoon…',
  };

  static const Map<AssistantLanguage, String> listeningPaused = {
    AssistantLanguage.hindi: 'Mic रुक गया। फिर से tap करें।',
    AssistantLanguage.english: 'Microphone paused. Tap again to resume.',
    AssistantLanguage.hinglish:
        'Mic pause ho gaya. Resume karne ke liye tap karein.',
  };

  static const Map<AssistantLanguage, String> processingQuery = {
    AssistantLanguage.hindi: 'सोच रहा हूँ…',
    AssistantLanguage.english: 'Thinking…',
    AssistantLanguage.hinglish: 'Soch raha hoon…',
  };

  static const Map<AssistantLanguage, String> speakingResponse = {
    AssistantLanguage.hindi: 'जवाब दे रहा हूँ…',
    AssistantLanguage.english: 'Responding…',
    AssistantLanguage.hinglish: 'Jawab de raha hoon…',
  };

  // ═══════════════════════════════════════════════════════════════
  // NAVIGATION RESPONSES
  // ═══════════════════════════════════════════════════════════════

  static const Map<AssistantLanguage, String> navigatingTo = {
    AssistantLanguage.hindi: 'आपको वहाँ ले जा रहा हूँ…',
    AssistantLanguage.english: 'Taking you there…',
    AssistantLanguage.hinglish: 'Aapko wahan le ja raha hoon…',
  };

  static const Map<AssistantLanguage, String> cannotNavigate = {
    AssistantLanguage.hindi:
        'माफ करें, मैं आपको वहाँ नहीं ले जा सकता। Top panel से navigate करें।',
    AssistantLanguage.english:
        "Sorry, I can't navigate there directly. Please use the top panel.",
    AssistantLanguage.hinglish:
        'Sorry, wahan directly nahi ja sakta. Top panel se navigate karein.',
  };

  // ═══════════════════════════════════════════════════════════════
  // GAME SCREEN RESPONSES
  // ═══════════════════════════════════════════════════════════════

  static const Map<AssistantLanguage, String> gameSessionStarted = {
    AssistantLanguage.hindi:
        'शुरू हो गया! बोलना शुरू करें और "done" कहकर खत्म करें।',
    AssistantLanguage.english:
        'Started! Begin speaking and say "done" to finish.',
    AssistantLanguage.hinglish:
        'Shuru ho gaya! Bolna shuru karein aur "done" bol ke khatam karein.',
  };

  static const Map<AssistantLanguage, String> gameSessionEnded = {
    AssistantLanguage.hindi: 'बातचीत खत्म हुई। मिलते हैं!',
    AssistantLanguage.english: 'Conversation ended. See you!',
    AssistantLanguage.hinglish: 'Baatceet khatam. Phir milenge!',
  };

  // ═══════════════════════════════════════════════════════════════
  // NAAM JAAP SCREEN
  // ═══════════════════════════════════════════════════════════════

  static const Map<AssistantLanguage, String> naamJaapStarted = {
    AssistantLanguage.hindi: 'नाम जाप शुरू हो गया। शांत मन से ध्यान करें।',
    AssistantLanguage.english: 'Naam Jaap has started. Focus and be calm.',
    AssistantLanguage.hinglish:
        'Naam Jaap shuru ho gaya. Shant man se dhyan karein.',
  };

  static const Map<AssistantLanguage, String> naamJaapCompleted = {
    AssistantLanguage.hindi:
        'नाम जाप पूरा हुआ। बहुत अच्छे! ईश्वर आपका भला करें।',
    AssistantLanguage.english:
        'Naam Jaap completed. Well done! May God bless you.',
    AssistantLanguage.hinglish:
        'Naam Jaap poora hua. Bahut achhe! Ishwar aapka bhala kare.',
  };

  // ═══════════════════════════════════════════════════════════════
  // REAL-TIME DATA
  // ═══════════════════════════════════════════════════════════════

  static const Map<AssistantLanguage, String> fetchingRealTimeData = {
    AssistantLanguage.hindi: 'जानकारी खोज रहा हूँ…',
    AssistantLanguage.english: 'Looking up the latest information…',
    AssistantLanguage.hinglish: 'Latest info dhoondh raha hoon…',
  };

  static const Map<AssistantLanguage, String> realTimeDataNotFound = {
    AssistantLanguage.hindi:
        'अभी की जानकारी नहीं मिल पाई। मेरे पास जो है उससे जवाब देता हूँ।',
    AssistantLanguage.english:
        "Couldn't find real-time data. I'll answer with what I know.",
    AssistantLanguage.hinglish:
        'Real-time info nahi mili. Jo pata hai ussi se jawab deta hoon.',
  };

  // ═══════════════════════════════════════════════════════════════
  // UTILITY METHOD
  // ═══════════════════════════════════════════════════════════════

  /// Get a localized string from a map, defaulting to Hinglish
  static String get(
    Map<AssistantLanguage, String> strings, {
    AssistantLanguage language = AssistantLanguage.hinglish,
  }) {
    return strings[language] ??
        strings[AssistantLanguage.hinglish] ??
        strings.values.first;
  }

  /// Detect language from a route or locale string
  static AssistantLanguage detectLanguage(String? locale) {
    if (locale == null) return AssistantLanguage.hinglish;
    final l = locale.toLowerCase();
    if (l.contains('en') && !l.contains('hi')) return AssistantLanguage.english;
    if (l == 'hi-in' || l == 'hi') return AssistantLanguage.hindi;
    return AssistantLanguage.hinglish;
  }

  /// Build a language instruction for the AI system prompt
  static String buildLanguageInstruction(AssistantLanguage language) {
    switch (language) {
      case AssistantLanguage.hindi:
        return 'Respond ONLY in Hindi (Devanagari script). '
            'Use simple, friendly, conversational Hindi.';
      case AssistantLanguage.english:
        return 'Respond ONLY in English. '
            'Use simple, friendly, conversational English.';
      case AssistantLanguage.hinglish:
        return 'Respond in Hinglish — a natural mix of Hindi and English. '
            'Use Roman script (not Devanagari). '
            'Keep it casual, friendly, and easy to understand.';
    }
  }
}
