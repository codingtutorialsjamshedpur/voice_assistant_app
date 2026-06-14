/// ════════════════════════════════════════════════════════════════
/// Guidance Scripts — Pre-written AI voice guidance scripts
/// ════════════════════════════════════════════════════════════════
///
/// Contains template scripts for common user scenarios so the AI
/// can provide consistent, friendly, and accurate voice guidance.
///
/// Supports Hindi, Hinglish, and English.
/// Mapped to task.md Task 3.2: Create Screen-Specific Guidance Scripts
/// ════════════════════════════════════════════════════════════════
library;

class GuidanceScripts {
  // ── Singleton ────────────────────────────────────────────────
  GuidanceScripts._();

  // ═══════════════════════════════════════════════════════════════
  // APP INTRODUCTION
  // ═══════════════════════════════════════════════════════════════

  static const String appIntroductionHindi = '''
नमस्ते! मैं CTJ VOICE CHAT हूँ, आपका AI वॉइस असिस्टेंट। 
यह ऐप Sourav Kumar ने बनाई है।
इस ऐप में आप मुझसे बात कर सकते हैं, गेम खेल सकते हैं, नाम जाप कर सकते हैं, और बहुत कुछ।
मैं हिंदी, अंग्रेजी, और हिंग्लिश — तीनों में बात कर सकता हूँ।
बस मुझसे कोई भी सवाल पूछें!
''';

  static const String appIntroductionEnglish = '''
Hello! I'm CTJ VOICE CHAT, your AI voice assistant.
This app was built by Sourav Kumar.
You can chat with me, play games, do Naam Jaap, set reminders, and much more.
I understand Hindi, English, and Hinglish.
Just ask me anything!
''';

  static const String appIntroductionHinglish = '''
Hello! Main CTJ VOICE CHAT hoon, aapka AI voice assistant.
Yeh app Sourav Kumar ne banaya hai.
Aap mujhse baat kar sakte hain, games khel sakte hain, Naam Jaap kar sakte hain, aur bahut kuch.
Main Hindi, English aur Hinglish — teeno mein samajhta hoon.
Bas koi bhi sawaal poochh lein!
''';

  // ═══════════════════════════════════════════════════════════════
  // HOW TO USE THE APP
  // ═══════════════════════════════════════════════════════════════

  static const String howToUseHindi = '''
इस ऐप को use करना बहुत आसान है।
नीचे एक input panel है जहाँ आप बोल या टाइप कर सकते हैं।
माइक्रोफोन बटन दबाएं और बोलना शुरू करें।
जब done हो जाएं, तो फिर से बटन दबाएं।
ऊपर एक panel है जिससे आप अलग-अलग स्क्रीन पर जा सकते हैं।
''';

  static const String howToUseEnglish = '''
Using this app is very simple.
There's an input panel at the bottom where you can speak or type.
Press the microphone button and start talking.
When you're done, press the button again.
The top panel lets you navigate to different screens.
''';

  static const String howToUseHinglish = '''
Yeh app use karna bahut easy hai.
Neeche ek input panel hai jahan aap bol ya type kar sakte hain.
Microphone button press karein aur bolna shuru karein.
Jab done ho jaayein, button dobara press karein.
Upar ek panel hai jisse aap alag screens pe ja sakte hain.
''';

  // ═══════════════════════════════════════════════════════════════
  // NAVIGATION HELP
  // ═══════════════════════════════════════════════════════════════

  static const String navigationHelpHindi = '''
ऊपर के panel में आप अलग-अलग screens पर जा सकते हैं।
Voice Chat, Game, Naam Jaap, History, और Settings — सब वहाँ हैं।
बस उस screen के icon पर tap करें जहाँ आप जाना चाहते हैं।
''';

  static const String navigationHelpEnglish = '''
The top panel lets you navigate between all app screens.
You can go to Voice Chat, Game, Naam Jaap, History, and Settings from there.
Just tap the icon of the screen you want to visit.
''';

  static const String navigationHelpHinglish = '''
Upar ke panel se aap alag screens pe ja sakte hain.
Voice Chat, Game, Naam Jaap, History, Settings — sab wahan hain.
Bas uss screen ke icon pe tap karein jahan jaana chahte hain.
''';

  // ═══════════════════════════════════════════════════════════════
  // GESTURE EXPLANATIONS
  // ═══════════════════════════════════════════════════════════════

  static const String gestureExplanationHindi = '''
इस ऐप में gestures से काम करना बहुत आसान है।
एक बार tap — कुछ शुरू करें या रोकें।
दो बार tap (double tap) — screen से वापस जाएं या session खत्म करें।
देर तक दबाए रखें (long press) — extra options देखें।
''';

  static const String gestureExplanationEnglish = '''
Using gestures in this app is very easy.
Single tap — start or pause something.
Double tap — go back or end a session.
Long press — see extra options.
''';

  static const String gestureExplanationHinglish = '''
Is app mein gestures se kaam karna bahut easy hai.
Ek baar tap — kuch shuru karein ya rokein.
Do baar tap (double tap) — screen se wapas jaayein ya session khatam karein.
Der tak press rakhein (long press) — extra options dekhein.
''';

  // ═══════════════════════════════════════════════════════════════
  // VOICE ASSISTANT GAME GUIDANCE
  // ═══════════════════════════════════════════════════════════════

  static const String voiceGameIntroHindi = '''
Voice Assistant Game में आप मुझसे बात कर सकते हैं!
जब आप बोलना शुरू करें, तो बस बोलते रहें।
जब done हो जाएं, तो "done" या "हो गया" कहें।
मैं आपकी बात सुनूंगा और जवाब दूंगा।
Orb पर एक बार tap करें — mic pause होगी।
Orb पर दो बार tap करें — conversation खत्म होगी।
''';

  static const String voiceGameIntroEnglish = '''
In the Voice Assistant Game, you can talk to me freely!
When you start speaking, just keep talking.
When you're done, say "done" or "ho gaya".
I'll listen and reply to you.
Single tap on the Orb — pauses the microphone.
Double tap on the Orb — ends the conversation.
''';

  static const String voiceGameIntroHinglish = '''
Voice Assistant Game mein aap mujhse baat kar sakte hain!
Jab aap bolna shuru karein, bas bolte rahein.
Done hone par "done" ya "ho gaya" bolein.
Main sunuunga aur jawab dunga.
Orb pe ek tap — mic pause.
Orb pe do tap — conversation khatam.
''';

  // ═══════════════════════════════════════════════════════════════
  // FEATURE DISCOVERY
  // ═══════════════════════════════════════════════════════════════

  static const String featureDiscoveryHindi = '''
इस ऐप में बहुत सारी features हैं!
Voice Chat में AI से बात करें।
Game Hub में Tic Tac Toe और Voice Assistant Game खेलें।
Naam Jaap में मंत्र दोहराएं।
Alarm में अपना alarm set करें।
Reminder में reminders बनाएं।
Wallpaper में app का background बदलें।
Voice Studio में voice memos record करें।
Language Coach में भाषा सीखें।
History में पुरानी बातचीत देखें।
''';

  static const String featureDiscoveryEnglish = '''
This app has many amazing features!
Voice Chat — talk to the AI assistant.
Game Hub — play Tic Tac Toe and the Voice Assistant Game.
Naam Jaap — repeat mantras with a counter.
Alarm — set alarms for any time.
Reminder — create and manage reminders.
Wallpaper — change the app background.
Voice Studio — record voice memos.
Language Coach — practice pronunciation in multiple languages.
History — review past conversations.
''';

  static const String featureDiscoveryHinglish = '''
Is app mein bahut saari features hain!
Voice Chat — AI se baat karein.
Game Hub — Tic Tac Toe aur Voice Assistant Game khelo.
Naam Jaap — mantra ka counter ke saath repetition karein.
Alarm — kisi bhi time ke liye alarm set karein.
Reminder — reminders banayein aur manage karein.
Wallpaper — app ka background badlein.
Voice Studio — voice memos record karein.
Language Coach — alag languages mein pronunciation seekhein.
History — purani baatein dekhein.
''';

  // ═══════════════════════════════════════════════════════════════
  // DEVELOPER INFORMATION
  // ═══════════════════════════════════════════════════════════════

  static const String developerInfoHindi = '''
यह ऐप Sourav Kumar ने बनाई है।
Developer के बारे में अधिक जानकारी के लिए About screen पर जाएं।
Top panel से About screen select कर सकते हैं।
''';

  static const String developerInfoEnglish = '''
This app was developed by Sourav Kumar.
For more information about the developer, visit the About screen.
You can find the About screen in the top panel.
''';

  static const String developerInfoHinglish = '''
Yeh app Sourav Kumar ne banaya hai.
Developer ke baare mein aur jaankari ke liye About screen pe jaayein.
Top panel se About screen select kar sakte hain.
''';

  // ═══════════════════════════════════════════════════════════════
  // ERROR & FALLBACK RESPONSES
  // ═══════════════════════════════════════════════════════════════

  static const String errorFallbackHindi =
      'माफ कीजिए, मुझे समझ नहीं आया। कृपया फिर से कहें।';
  static const String errorFallbackEnglish =
      "Sorry, I didn't understand. Please say that again.";
  static const String errorFallbackHinglish =
      'Maafi chahta hoon, samajh nahi aaya. Please dobara bolein.';

  // ═══════════════════════════════════════════════════════════════
  // CONTEXT-AWARE SCREEN INTRODUCTIONS
  // ═══════════════════════════════════════════════════════════════

  /// Returns a short intro script for the user when they arrive on a new screen
  static String getScreenIntro(String route, {String language = 'hinglish'}) {
    switch (route) {
      case '/voice-chat':
        return _localize(
          hindi:
              'आप Voice Chat पर हैं। मुझसे कुछ भी पूछें या बताएं। माइक्रोफोन बटन दबाएं और बोलना शुरू करें।',
          english:
              'You are on Voice Chat. Ask me anything. Press the microphone button and start talking.',
          hinglish:
              'Aap Voice Chat pe hain. Mujhse kuch bhi poochhein. Microphone button press karein aur bolna shuru karein.',
          language: language,
        );
      case '/game':
        return _localize(
          hindi:
              'Game Hub में आपका स्वागत है! यहाँ Tic Tac Toe और Voice Assistant Game उपलब्ध हैं।',
          english:
              'Welcome to Game Hub! Tic Tac Toe and Voice Assistant Game are available here.',
          hinglish:
              'Game Hub mein aapka swagat hai! Yahan Tic Tac Toe aur Voice Assistant Game uplabdh hain.',
          language: language,
        );
      case '/game-play':
        return _localize(
          hindi: voiceGameIntroHindi,
          english: voiceGameIntroEnglish,
          hinglish: voiceGameIntroHinglish,
          language: language,
        );
      case '/naam-jaap':
        return _localize(
          hindi:
              'Naam Jaap screen पर आपका स्वागत है। Slider से count चुनें और Start बटन दबाएं।',
          english:
              'Welcome to Naam Jaap. Set your count using the slider and press Start.',
          hinglish:
              'Naam Jaap screen pe aapka swagat hai. Slider se count chunein aur Start dabayein.',
          language: language,
        );
      case '/history':
        return _localize(
          hindi: 'History screen पर आपकी पुरानी बातचीत दिख रही है।',
          english: 'You can see your past conversations on the History screen.',
          hinglish: 'History screen pe aapki purani baatceet dikh rahi hai.',
          language: language,
        );
      case '/settings':
        return _localize(
          hindi:
              'Settings screen पर आप language, TTS speed, और notification configure कर सकते हैं।',
          english:
              'In Settings you can configure language, TTS speed, and notifications.',
          hinglish:
              'Settings mein aap language, TTS speed aur notifications configure kar sakte hain.',
          language: language,
        );
      case '/about':
        return _localize(
          hindi: developerInfoHindi,
          english: developerInfoEnglish,
          hinglish: developerInfoHinglish,
          language: language,
        );
      default:
        return _localize(
          hindi: 'आप एक नई screen पर हैं। मुझसे कुछ भी पूछें!',
          english: 'You are on a new screen. Ask me anything!',
          hinglish: 'Aap ek nayi screen pe hain. Kuch bhi poochhein!',
          language: language,
        );
    }
  }

  /// Common FAQ-style responses for the AI to use
  static Map<String, String> get faqHinglish => {
        'yeh app kya hai': appIntroductionHinglish,
        'what is this app': appIntroductionEnglish,
        'yeh app kya karta hai': appIntroductionHinglish,
        'kaise use karein': howToUseHinglish,
        'how to use': howToUseEnglish,
        'wapas kaise jayein': navigationHelpHinglish,
        'how to go back': navigationHelpEnglish,
        'kaun banaya': developerInfoHinglish,
        'who made this': developerInfoEnglish,
        'developer kaun hai': developerInfoHinglish,
        'games kahan hain': featureDiscoveryHinglish,
        'what can i do': featureDiscoveryEnglish,
        'kya features hain': featureDiscoveryHindi,
        'gesture kya hain': gestureExplanationHinglish,
        'how to tap': gestureExplanationEnglish,
      };

  // ── Private helpers ────────────────────────────────────────────

  static String _localize({
    required String hindi,
    required String english,
    required String hinglish,
    required String language,
  }) {
    switch (language.toLowerCase()) {
      case 'hindi':
      case 'hi':
      case 'hi-in':
        return hindi;
      case 'english':
      case 'en':
      case 'en-us':
      case 'en-gb':
        return english;
      default:
        return hinglish;
    }
  }
}
